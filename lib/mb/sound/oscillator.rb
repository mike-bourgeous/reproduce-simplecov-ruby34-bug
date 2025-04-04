require 'midi-message'
require 'nibbler'

module MB
  module Sound
    # An oscillator that can generate different wave types.  This can be used
    # to generate sound, or as an LFO (low-frequency oscillator).  It can also
    # generate noise with various statistical distributions by setting advance
    # to 0 and random_advance to 2*pi.  All oscillators should start at 0
    # (except for e.g. square, which doesn't have a zero), and rise first
    # before falling, unless a phase offset is specified.
    #
    # An exponential distortion can be applied to the output before or after
    # values are scaled to the desired output range.
    class Oscillator
      # Default note that is used as tuning reference
      DEFAULT_TUNE_NOTE = 69 # A4

      # Default frequency that the tuning reference should be
      DEFAULT_TUNE_FREQ = 440

      # Sets the MIDI note number to use as tuning reference.  C4 (middle C) is
      # note 60, A4 is note 69.  This only affects future frequency changes;
      # existing Tones, Notes, or Oscillators will not be modified.  The
      # default is DEFAULT_TUNE_NOTE (A4, note number 69).
      def self.tune_note=(note_number)
        @tune_note = note_number
      end

      # Returns the MIDI note number used as tuning reference.  This note will
      # be tuned to the tune_freq.  See also the calc_freq method.  The default
      # is DEFAULT_TUNE_NOTE (note 69, A4).
      def self.tune_note
        @tune_note ||= DEFAULT_TUNE_NOTE
      end

      # Sets the frequency in Hz of the tune_note.  This only affects future
      # frequency changes.  Existing Tones, Notes, or Oscillators will not be
      # changed.  The default is DEFAULT_TUNE_FREQ (440Hz).  Set to nil to
      # restore the default.
      def self.tune_freq=(freq_hz)
        @tune_freq = freq_hz
      end

      # Returns the frequency in Hz that the tune_note should be.  The default
      # is DEFAULT_TUNE_FREQ (440Hz).
      def self.tune_freq
        @tune_freq ||= DEFAULT_TUNE_FREQ
      end

      # Calculates a frequency in Hz for the given MIDI note number and
      # detuning in cents, based on the tuning parameters set by the tune_freq=
      # and tune_note= class methods and using 12 tone equal temperament
      # (defaults to 440Hz A4).
      def self.calc_freq(note_number, detune_cents = 0)
        tune_freq * 2 ** ((note_number + detune_cents / 100.0 - tune_note) / 12.0)
      end
    end
  end
end
