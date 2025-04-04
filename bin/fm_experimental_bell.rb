#!/usr/bin/env ruby
# A tubular bell sound based in part on the T.BL-EXPA preset included with
# Dexed.

require 'bundler/setup'
require 'mb-sound'

repeat = !!ARGV.delete('--loop')

# TODO: Build an abstraction around switching between Jack and MIDI files for
# input, and FLAC files for output, for use by all synthesizers
jack = MB::Sound::JackFFI[]
output = jack.output(channels: 1, connect: [['system:playback_1', 'system:playback_2']])
midi = MB::Sound::MIDI::MIDIFile.new(ARGV[0]) if ARGV[0]&.end_with?('.mid') # TODO: Add a clock source based on jackd frames
manager = MB::Sound::MIDI::Manager.new(jack: jack, input: midi, connect: ARGV[0])

OSC_COUNT = ENV['OSC_COUNT']&.to_i || 9
voices = OSC_COUNT.times.map { |i|
  freq_constants = []

  # TODO: Use Tee instead of .dup for base frequencies in synths?
  base = 440.constant(smoothing: false)
  bfreq = -> { 2 ** base.dup.tap { |z| freq_constants << z }.log2 } # smooth after log2 for portamento

  r_ratio = (8 * 3.5).constant.named('R Ratio')
  r_osc = (bfreq.call * r_ratio).tone.complex_sine.at(1).named('R')
  r_env = MB::Sound.adsr(0.05, 4, 0.1, 4).named('R Envelope').db(20)
  r_out = (r_osc * r_env).named('R Out')
  rq_const = 1.4.constant.named('R into Q')

  q_ratio = 8.constant.named('Q Ratio')
  q_osc = (bfreq.call * q_ratio).tone.complex_sine.at(1).pm(r_out * rq_const).named('Q')
  q_env = MB::Sound.adsr(2, 3, 0.7, 3).named('Q Envelope').db(30) * 0.1632.hz.sine.at(0.5..1.5)
  q_out = (q_osc * q_env).named('Q Out')
  qb_const = 0.15.constant.named('Q into B')
  qa_const = 0.25.constant.named('Q into A')
  q1, q2, q3 = q_out.tee(3)

  # 7 mils detuned up, 3.5 ratio
  b_ratio = 3.5.constant.named('B Ratio')
  b_osc = (bfreq.call * b_ratio * (2 ** (2.0 / 1000.0))).tone.complex_sine.at(1).pm(q2 * qb_const).named('B')
  b_env = MB::Sound.adsr(0, 5, 0.2, 4).named('B Envelope').db(30) * 0.223.hz.sine.at(0.8..1.1)
  b_out = (b_osc * b_env).named('B Out')

  # 7 mils up
  ba_const = 1.6.constant.named('B into A')
  a_osc = (bfreq.call * (2 ** (2.0 / 1000.0))).tone.complex_sine.at(1).pm(b_out * ba_const + q1 * qa_const).named('A')
  a_env = MB::Sound.adsr(0, 6, 0.5, 5).named('A Envelope').db(30) * 0.111.hz.sine.at(0.9..1.0)
  a_out = (a_osc * a_env).named('A Out')

  # 5 mils up, 3.5 ratio
  d_ratio = 3.5.constant.named('D Ratio')
  d_osc = (bfreq.call * d_ratio * (2 ** (3.0 / 1000.0))).tone.complex_sine.at(1).named('D')
  d_env = MB::Sound.adsr(0, 5, 0.13, 4).named('D Envelope').db(30) * 0.157.hz.sine.at(0.3..1.1)
  d_out = (d_osc * d_env).named('D Out')

  # 2 mils up
  dc_const = 1.6.constant.named('D into C')
  c_osc = (bfreq.call * (2 ** (1.0 / 1000.0))).tone.complex_sine.at(1).pm(d_out * dc_const).named('C')
  c_env = MB::Sound.adsr(0, 6, 0.55, 5).named('C Envelope').db(30) * 0.317.hz.sine.at(0.9..1.0)
  c_out = (c_osc * c_env).named('C Out')

  sum = a_out + c_out + (q3 * 0.05)

  g = sum.filter(10000.hz.lowpass) # Try to cut down on aliasing chalkboard noise

  final = g * 0.5

  MB::Sound::MIDI::GraphVoice.new(
    final,
    update_rate: manager.update_rate,
    amp_envelopes: ['A Envelope', 'C Envelope'],
    freq_constants: freq_constants
  ).named('FM Tubular Bell').tap { |v|
    v.on_velocity(['B into A', 'D into C'], range: 0.5..1.5, relative: true)
    v.on_velocity(['A Out', 'C Out'], range: 0.5..1.0, relative: true)
    #v.on_cc(1, ['B Ratio', 'D Ratio'], range: 3.5..4.0, relative: false)
    v.on_cc(1, ['Q into B'], range: 0.1..0.5, relative: false)
    v.on_cc(1, ['Q into A'], range: 0.2..4.0, relative: false)
  }
}

pool = MB::Sound::MIDI::VoicePool.new(
  manager,
  voices
)
output_chain = pool.softclip(0.8, 0.95)

if ENV['DEBUG'] == '1'
  puts 'saving before graph'
  File.write('/tmp/pm_bass_before.dot', output_chain.graphviz)
  `dot -Tpng /tmp/pm_bass_before.dot -o /tmp/pm_bass_before.png`
end

puts MB::U.syntax(manager.to_acid_xml, :xml)

begin
  puts 'starting loop'
  loop do
    manager.update
    output.write([output_chain.sample(output.buffer_size)])

    if midi&.empty?
      pool.all_off
      midi.seek(0) if repeat
    end
    break if midi&.empty? && !pool.active? && !repeat
  end
ensure
  if ENV['DEBUG'] == '1'
    puts 'saving after graph'
    File.write('/tmp/pm_bass_after.dot', output_chain.graphviz)
    `dot -Tpng /tmp/pm_bass_after.dot -o /tmp/pm_bass_after.png`
  end
end
