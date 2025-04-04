RSpec.describe MB::Sound::Note do
  describe '#initialize' do
    context 'when given a MIDI note number' do
      let!(:note_names) {
        [
          'C',
          'Cs',
          'D',
          'Ds',
          'E',
          'F',
          'Fs',
          'G',
          'Gs',
          'A',
          'As',
          'B'
        ]
      }

      (0..127).each_slice(12).each do |slice|
        context "for notes in #{slice.first}..#{slice.last}" do
          it "can create MIDI notes" do
            slice.each_with_index do |n, idx|
              note = MB::Sound::Note.new(n)
              octave = n / 12 - 1
              expect(note.name).to eq("#{note_names[idx]}#{octave}")
              expect(note.frequency.round(2)).to eq((440 * 2 ** ((n - 69) / 12.0)).round(2))
              expect(note.number).to eq(n)
            end
          end

          it 'preserves the MIDI note name and number when reconstructing from frequency' do
            slice.each_with_index do |n, idx|
              orig = MB::Sound::Note.new(n)
              note = MB::Sound::Note.new(orig.frequency.hz)
              expect(note.number).to eq(n)
              expect(note.name).to eq(orig.name)
            end
          end

          it 'preserves the MIDI note name and number when reconstructing from name' do
            slice.each_with_index do |n, idx|
              orig = MB::Sound::Note.new(n)
              note = MB::Sound::Note.new(orig.name)
              expect(note.number).to eq(n)
              expect(note.name).to eq(orig.name)
            end
          end

          it 'preserves the MIDI note name and number when reconstructing from number' do
            slice.each_with_index do |n, idx|
              orig = MB::Sound::Note.new(n)
              note = MB::Sound::Note.new(orig.number)
              expect(note.number).to eq(n)
              expect(note.name).to eq(orig.name)
            end
          end
        end
      end

      it 'can create fractional MIDI notes' do
        note = MB::Sound::Note.new(60.2)
        expect(note.detune).to eq(20)
        expect(note.name).to eq('C4')

        note = MB::Sound::Note.new(60.5)
        expect(note.detune).to eq(-50)
        expect(note.name).to eq('Cs4')

        note = MB::Sound::Note.new(60.51)
        expect(note.detune).to eq(-49)
        expect(note.name).to eq('Cs4')

        note = MB::Sound::Note.new(59.9)
      end

      (58..72).each do |n|
        [0.0, 0.1, 0.49, 0.5, 0.51, 0.9, 1.0].each do |d|
          number = n + d
          it "creates number and detuning that match note #{number}" do
            note = MB::Sound::Note.new(number)
            expect((note.number + note.detune * 0.01).round(2)).to eq(number)
          end
        end
      end

      it 'produces a Tone that can be played' do
        expect(MB::Sound::Note.new(56).generate(1000).max).not_to eq(0)
      end

      it 'can parse an Integer note number from a String' do
        note = MB::Sound::Note.new('61')
        expect(note.number).to eq(61)
        expect(note.name).to eq('Cs4')
        expect(note.fancy_name).to eq("C\u266f4")
      end

      it 'can parse a fractional note number from a String' do
        note = MB::Sound::Note.new('63.12')
        expect(note.number.round(5)).to eq(63)
        expect(note.detune.round(5)).to eq(12)
        expect(note.name).to eq('Eb4')
        expect(note.fancy_name).to eq("E\u266d4")
      end
    end

    context 'when given a Tone object' do
      let!(:hz) { MB::Sound::Oscillator::DEFAULT_TUNE_FREQ }
      let!(:n) { MB::Sound::Oscillator::DEFAULT_TUNE_NOTE }

      it 'finds octaves of the tuning reference' do
        expect(MB::Sound::Note.new(hz.hz).number).to eq(n)
        expect(MB::Sound::Note.new((hz * 2).hz).number).to eq(n + 12)
        expect(MB::Sound::Note.new((hz / 2).hz).number).to eq(n - 12)
      end

      it 'finds intervals from the tuning reference' do
        expect(MB::Sound::Note.new((hz * 1.25).hz).number).to eq(n + 4)
        expect(MB::Sound::Note.new((hz * 1.5).hz).number).to eq(n + 7)
      end

      it 'preserves attributes of the Tone' do
        n = MB::Sound::Note.new(hz.hz.ramp.at(-3.db).for(2.123))
        expect(n.wave_type).to eq(:ramp)
        expect(n.frequency.round(4)).to eq(hz.round(4))
        expect(n.duration).to eq(2.123)
        expect(n.amplitude).to eq(-3.db)
      end

      it 'produces a Tone that can be played' do
        expect(MB::Sound::Note.new(144.hz).generate(1000).max).not_to eq(0)
      end
    end

    context 'when given a note name' do
      it 'preserves the same note name and number for each MIDI note' do
        (0..127).each do |n|
          by_num = MB::Sound::Note.new(n)
          by_name = MB::Sound::Note.new(by_num.name)
          expect(by_name.name).to eq(by_num.name)
          expect(by_name.number).to eq(by_num.number)
        end
      end

      it 'can accept #, U+266f, or s for sharps' do
        expect(MB::Sound::Note.new('C#4').number).to eq(61)
        expect(MB::Sound::Note.new('Cs4').number).to eq(61)
        expect(MB::Sound::Note.new("C\u266f4").number).to eq(61)
      end

      it 'can accept b or U+266d for flats' do
        expect(MB::Sound::Note.new('Eb4').number).to eq(63)
        expect(MB::Sound::Note.new("E\u266d4").number).to eq(63)
      end

      it 'can accept U+266e for neutrals' do
        expect(MB::Sound::Note.new("E\u266e4").number).to eq(64)
      end

      it 'can accept U+266f for sharps' do
        expect(MB::Sound::Note.new("F\u266f4").number).to eq(66)
      end

      it 'can translate a half-step accidental to the neighboring note' do
        expect(MB::Sound::Note.new('Cb4').name).to eq('B3')
        expect(MB::Sound::Note.new('Bs3').name).to eq('C4')
      end

      it 'can read small detuning amounts' do
        expect(MB::Sound::Note.new('D4+20').detune).to eq(20)
        expect(MB::Sound::Note.new('D4-20.1').detune).to eq(-20.1)

        n = MB::Sound::Note.new('D4-50')
        expect(n.detune).to eq(-50)
        expect(n.name).to eq('D4')

        n = MB::Sound::Note.new('D4+50')
        expect(n.detune).to eq(-50)
        expect(n.name).to eq('Ds4')
      end

      it 'can read large detuning amounts' do
        n = MB::Sound::Note.new('D4+99')
        expect(n.detune).to eq(-1)
        expect(n.name).to eq('Ds4')

        # The note name is rounded to the closest named note
        n = MB::Sound::Note.new('D4+101')
        expect(n.detune).to eq(1)
        expect(n.name).to eq('Eb4')

        n = MB::Sound::Note.new('D4-101')
        expect(n.detune).to eq(-1)
        expect(n.name).to eq('Cs4')

        n = MB::Sound::Note.new('Cs4-101')
        expect(n.detune).to eq(-1)
        expect(n.name).to eq('C4')

        n = MB::Sound::Note.new('D4-1200.5')
        expect(n.detune).to eq(-0.5)
        expect(n.name).to eq('D3')
      end

      it 'gives the right frequency for A4' do
        expect(MB::Sound::Note.new('A4').frequency.round(5)).to eq(440)
      end

      it 'produces a Tone that can be played' do
        expect(MB::Sound::Note.new('C4').generate(1000).max).not_to eq(0)
      end
    end

    context 'when the tuning reference is changed' do
      after(:each) {
        MB::Sound::Oscillator.tune_note = nil
        MB::Sound::Oscillator.tune_freq = nil
        expect(MB::Sound::A4.frequency.round(5)).to eq(440)
      }

      it 'changes new notes but leaves existing notes alone' do
        a4 = MB::Sound::A4
        expect(a4.frequency.round(5)).to eq(440)

        MB::Sound::Oscillator.tune_freq = 432 # it's got bad frequencies!
        a4_lower = MB::Sound::A4
        expect(a4.frequency.round(5)).to eq(440)
        expect(a4_lower.frequency.round(5)).to eq(432)
      end

      it 'can use a different tuning note' do
        MB::Sound::Oscillator.tune_note = 47 # B2
        MB::Sound::Oscillator.tune_freq = 120 # 49.36 cents flat from A440 tuning to get exactly 120Hz

        a4 = MB::Sound::A4
        b4 = MB::Sound::B4
        expect(a4.frequency.round(5)).not_to eq(440)
        expect(120.hz.to_note.number.round(5)).to eq(47)
        expect(120.hz.to_note.detune.round(5)).to eq(0)
        expect(b4.frequency.round(5)).to eq(480)
      end
    end

    it 'raises an error if given an unsupported parameter for note creation' do
      expect { MB::Sound::Note.new({ not: 'valid' }) }.to raise_error(ArgumentError, /Note from/)
    end

    context 'when given Unicode
    it '
  end

  describe '#fancy_name' do
    it 'uses U+266d for flat' do
      expect(MB::Sound::Note.new('A3-51').fancy_name).to eq("A\u266d3")
    end

    it 'uses U+266f for sharp' do
      expect(MB::Sound::Note.new('A3+51').fancy_name).to eq("A\u266f3")
    end
  end

  describe '#white_key?' do
    it 'returns true if there is no accidental' do
      expect(MB::Sound::C3.white_key?).to eq(true)
    end

    it 'returns false if there is an accidental' do
      expect(MB::Sound::Cs3.white_key?).to eq(false)
    end

    it 'returns true for C-flat and E-sharp' do
      expect(MB::Sound::Cb3.white_key?).to eq(true)
      expect(MB::Sound::Es3.white_key?).to eq(true)
    end
  end

  describe '#black_key?' do
    it 'returns false if there is no accidental' do
      expect(MB::Sound::C3.black_key?).to eq(false)
    end

    it 'returns true if there is an accidental' do
      expect(MB::Sound::Cs3.black_key?).to eq(true)
    end
  end
end
