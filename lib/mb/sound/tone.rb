module MB
  module Sound
    # Representation of a tone to generate or play.  Uses MB::Sound::Oscillator
    # for tone generation.
    class Tone
      # Initializes a representation of a simple generated waveform.
      #
      # +wave_type+ - One of the waveform types supported by MB::Sound::Oscillator (e.g. :sine).
      # +frequency+ - The frequency of the tone, in Hz at the given +:rate+.
      # +amplitude+ - The linear peak amplitude of the tone, or a Range.
      # +phase+ - The starting phase, in radians relative to a sine wave (0
      #           radians phase starts at 0 and rises).
      # +duration+ - How long the tone should play in seconds (default is 5s).
      # +rate+ - The sample rate to use to calculate the frequency.
      def initialize(wave_type: :sine, frequency: 440, amplitude: 0.1, phase: 0, duration: 5, rate: 48000)
        @wave_type = wave_type
        @oscillator = nil
        @noise = 0
        @amplitude_set = false
        @duration_set = false
        @phase_mod = nil
        @no_trigger = false
        set_frequency(frequency)
      end

      # Converts this Tone to the nearest Note based on its frequency.
      def to_note
        MB::Sound::Note.new(self)
      end

      # Converts this Tone to a MIDI note-on message from the midi-message gem.
      def to_midi(velocity: 64, channel: -1)
        to_note.to_midi(velocity: velocity, channel: channel)
      end

      def to_s
        inspect
      end

      private

      # Allows subclasses (e.g. Note) to change the frequency after construction.
      def set_frequency(freq)
        freq = freq.to_f if freq.is_a?(Numeric)
        @frequency = freq
        @oscillator&.frequency = @frequency
      end
    end
  end
end
