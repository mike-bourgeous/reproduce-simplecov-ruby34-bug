require 'fileutils'

RSpec.describe(MB::Sound::WindowMethods) do
  describe '#process' do
    let(:input) { 'sounds/synth0.flac' }
    let(:output) { 'tmp/process_test.flac' }
    let(:in_sound) { MB::Sound.read(input) }
    let(:out_sound) { MB::Sound.read(output) }

    before(:each) do
      FileUtils.mkdir_p('tmp')
      File.unlink(output) rescue nil
    end

    it 'can amplify sound' do
      MB::Sound.process(input, output) do |dfts|
        dfts.map { |c| c * 0.5 }
      end
      expect(out_sound.length).to eq(in_sound.length)
      expect(out_sound[0].length).to eq(in_sound[0].length)
      expect(out_sound.map { |c| c.max.round(4) }).to eq(in_sound.map { |c| (c.max * 0.5).round(4) })
    end

    it 'can reverse a sound' do
      MB::Sound.process(input, output) do |dfts|
        dfts.map(&:conj)
      end
      # For whatever reason there's a single-sample offset from #reverse to the
      # DFT reversal
      expect(out_sound.length).to eq(in_sound.length)
      expect(out_sound[0].length).to eq(in_sound[0].length)
      expect(MB::M.rol(out_sound[0], 1)).to eq(in_sound[0].reverse)
    end

    it 'can filter a sound' do
      MB::Sound.process(input, output) do |dfts|
        scale = Numo::SFloat.linspace(1, 0, dfts.first.size)
        dfts.map { |c| c * scale }
      end

      in_dft = MB::Sound.real_fft(in_sound)
      out_dft = MB::Sound.real_fft(out_sound)

      expect(out_dft[0][0..500].abs.sum.round(3)).to be > 0
      expect(out_dft[0][0..500].abs.sum.round(2)).to eq(in_dft[0][0..500].abs.sum.round(2))
      expect(out_dft[0][-10001..-1].abs.sum.round(3)).to be > 0
      expect(out_dft[0][-10001..-1].abs.sum.round(3)).to be < in_dft[0][-10001..-1].abs.sum.round(3) * 0.1
    end
  end

  pending '#process_split'
  pending '#process_overlap'
  pending '#process_time_stream'
  pending '#process_stream'
  pending '#analyze_multi_time_window'
  pending '#analyze_time_window'
  pending '#synthesize_time_window'
  pending '#analyze_window'
  pending '#synthesize_window'
  pending '#process_time_window'
  pending '#process_window'
end
