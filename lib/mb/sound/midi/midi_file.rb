require 'midilib'

module MB
  module Sound
    module MIDI
      # Reads from a MIDI file, returning MIDI data at the appropriate times
      # for each MIDI event.  Can be used by MB::Sound::MIDI::Manager to play a
      # MIDI file.
      #
      # This implements just enough compatibility with
      # MB::Sound::JackFFI::Input#read to work with MB::Sound::MIDI::Manager.
      #
      # This uses the midilib gem for MIDI parsing.  Due to limitations in the
      # midilib gem, this does not support MIDI files that change tempo.
      #
      # Also note that track names from midilib might include a trailing NUL
      # ("\x00") byte.  This happens with MIDI files exported from ACID Pro,
      # for example.
      #
      # Useful references:
      #  - https://www.cs.cmu.edu/~music/cmsip/readings/Standard-MIDI-file-format-updated.pdf
      class MIDIFile
        # A clock that may be passed to the constructor that returns whatever
        # value was last assigned to #clock_now=.
        class ConstantClock
          # The constant value assigned to the clock.
          attr_reader :clock_now

          # Initializes a constant-value clock, with an optional initial time.
          def initialize(time = 0)
            @clock_now = time.to_f
          end

          # Sets the value to be returned for the current time.
          def clock_now=(time)
            @clock_now = time.to_f
          end
        end

        # The MIDI filename that was given to the constructor.
        attr_reader :filename

        # The index of the next MIDI event to read, when its timestamp has
        # elapsed.
        attr_reader :index

        # The current playback time (in seconds) within the MIDI file.  See
        # #seek.
        attr_reader :elapsed

        # The number of events that could be read.
        attr_reader :count

        # The *approximate* duration of the MIDI file, in seconds.  This is the
        # maximum duration of all tracks, not just the track selected for
        # reading.
        #
        # This is just the time of the last event in the file, and doesn't
        # account for sounds' decay times.
        attr_reader :duration

        # The sequence object from the midilib gem that contains MIDI data from the file.
        attr_reader :seq

        # The full list of events that will be returned over time by #read.
        attr_reader :events

        # The track index given to the constructor.
        attr_reader :read_track

        # Reads MIDI data from the given +filename+.  Call #read repeatedly to
        # receive MIDI events based on elapsed time.
        #
        # The +:clock+ parameter accepts any object that responds to
        # :clock_now.  This allows playing a MIDI file at a speed other than
        # monotonic real time.
        #
        # If +:merge_tracks+ is false, then events will not be merged across
        # tracks, and #read will only return events from track +:read_track+.
        def initialize(filename, clock: MB::U, merge_tracks: true, read_track: 0)
          raise "Clock must respond to :clock_now" unless clock.respond_to?(:clock_now)
          @clock = clock

          @filename = filename

          @seq = ::MIDI::Sequence.new
          File.open(filename, 'rb') do |f|
            @seq.read(f)
          end

          @read_track = read_track
          track = @seq.tracks[read_track].dup

          if merge_tracks
            @seq.tracks[0..-1].each_with_index do |t, idx|
              next if idx == read_track
              track.merge(t.events)
            end
          end

          @duration = @seq.pulses_to_seconds(@seq.tracks.map(&:events).map(&:last).map(&:time_from_start).max)

          @events = track.events.freeze
          @count = @events.count

          @index = 0
          @elapsed = 0

          @notes = nil
          @note_stats = nil
          @note_channel_stats = []
        end

        # Returns an Array containing start and end times for all notes from
        # the #read_track (or all tracks if track merging was specified),
        # sorted by note start time.  These times do not account for variable
        # tempo.
        #
        #     {
        #       # The note channel (0-based)
        #       channel: 0..15,
        #
        #       # The note number
        #       note: 0..127,
        #
        #       # The note on and note off velocities
        #       on_velocity: 0..127,
        #       off_velocity: 0..127,
        #
        #       # The time when the note begins, in seconds, from the start of the file.
        #       on_time: Float,
        #
        #       # The time when the note ends, in seconds, from the start of the file.
        #       off_time: Float,
        #
        #       # If the sustain pedal was held when the note was released,
        #       # then this is the time when the sustain pedal was released
        #       # after the note was released.
        #       sustain_time: Float,
        #     }
        def notes
          @notes ||= event_notes(@events)
        end

        # Returns the minimum, median, and maximum note number used in the
        # #read_track, or 64 for each if there are no notes in the MIDI file.
        #
        # This may be useful for setting an initial scroll position of a piano
        # roll display, for example.
        #
        # If +:channel+ is not nil, then only stats for notes on the given
        # channel are returned.
        def note_stats(channel: nil)
          if channel
            @note_channel_stats[channel] ||= note_list_stats(notes, channel: channel)
          else
            @note_stats ||= note_list_stats(notes)
          end
        end

        # Returns an Array of channels (0-based) used in the MIDI file.
        def channels
          @channel_list ||= tracks.flat_map { |t| t[:event_channels] }.sort.uniq
        end

        private

        # Returns an array of all notes from the given MIDILib event list,
        # sorted by note start time.  This probably does not account for SMPTE
        # track offset (this is untested).
        def event_notes(events)
          channels = 16.times.map {
            {
              sustain: false,
              active_notes: {},
            }
          }
          note_list = []

          events.each do |e|
            next unless e.respond_to?(:channel)

            event_time = @seq.pulses_to_seconds(e.time_from_start)
            ch_info = channels[e.channel]
            ch_notes = ch_info[:active_notes]

            # TODO: This code has some similarity to code in the MIDI manager
            # and VoicePool; see if that can be deduplicated.
            case e
            when ::MIDI::NoteOn
              # Treat repeated note on events as a note off followed by note on
              # (Alternatives could include counting the number of note ons,
              # and waiting for that number of note offs)
              existing_note = ch_notes[e.note]
              if existing_note
                existing_note[:off_velocity] ||= existing_note[:on_velocity]
                existing_note[:off_time] ||= event_time
                existing_note[:sustain_time] ||= event_time
                note_list << existing_note
              end

              ch_notes[e.note] = {
                channel: e.channel,
                number: e.note,
                on_velocity: e.velocity,
                off_velocity: nil,
                on_time: event_time,
                off_time: nil,
                sustain_time: nil,
              }

            when ::MIDI::NoteOff
              existing_note = ch_notes[e.note]
              if existing_note
                # Using ||= in case of repeated note off events during a sustain
                existing_note[:off_velocity] ||= e.velocity
                existing_note[:off_time] ||= event_time

                unless ch_info[:sustain]
                  # If the sustain pedal isn't pressed, move the note into the completed note list
                  existing_note[:sustain_time] ||= event_time
                  note_list << existing_note
                  ch_notes.delete(e.note)
                end
              end

            when ::MIDI::Controller
              if e.controller == 64 # sustain pedal is CC 64
                # TODO: what about half/variable pedal?
                # TODO: what about sostenuto?
                if e.value >= 64
                  ch_info[:sustain] = true
                else
                  ch_info[:sustain] = false

                  ch_notes.select! { |_, n|
                    if n[:off_time]
                      # If the note has an off time, it was sustained.  Release it.
                      n[:sustain_time] = event_time
                      note_list << n

                      false
                    else
                      # Keep notes without an off time
                      true
                    end
                  }
                end
              end
            end
          end

          # If any notes weren't released at the end, set their release times
          # to the MIDI file duration
          channels.each do |ch_info|
            ch_info[:active_notes].each do |n|
              n[:off_velocity] ||= n[:on_velocity]
              n[:off_time] ||= @duration
              n[:sustain_time] ||= @duration
              note_list << n
            end
          end

          notes = note_list.sort_by! { |n| [n[:on_time], n[:channel], n[:number], n[:off_time], n[:velocity]] }

          notes
        end

        # Returns min, median, and max note numbers from the given list of
        # notes, or 64 for each value if the list is empty.  Filters to notes
        # on the given +:channel+ (0-based) if +:channel+ is not nil.
        def note_list_stats(notes, channel: nil)
          numbers = notes.select { |n| channel.nil? || n[:channel] == channel }.map { |n| n[:number] }.sort

          [
            numbers[0] || 64,
            numbers[numbers.length / 2] || 64,
            numbers[-1] || 64,
          ]
        end
      end
    end
  end
end
