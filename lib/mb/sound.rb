require 'cmath'
require 'numo/narray'

require 'mb-math'
require 'mb-util'

require_relative 'sound/version'

module MB
  # Convenience functions for making quick work of sound.
  #
  # Top-level namespace for the mb-sound library.
  module Sound
  end
end

require_relative 'sound/oscillator'
require_relative 'sound/tone'
require_relative 'sound/note'
require_relative 'sound/midi'
