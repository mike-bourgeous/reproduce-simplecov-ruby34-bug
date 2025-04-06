RSpec.describe('bin/midi_roll.rb', :aggregate_failures) do
  it 'can display a MIDI roll' do
    if ENV['INTERACTIVE_GDB'] == '1'
      system("gdb -x ./gdb_ruby_backtrace.gdb --args $(which ruby) bin/midi_roll.rb -r 2 -c 100 -n C3 spec/test_data/all_notes.mid 2>&1")
    end

    # unbuffer is from the expect package and uses a pseudoterminal to make gdb print colors
    text = `unbuffer gdb --batch -x ./gdb_ruby_backtrace.gdb --args $(which ruby) bin/midi_roll.rb -r 2 -c 100 -n C3 spec/test_data/all_notes.mid 2>&1`
    status = $?

    expect(status).to be_success

    lines = MB::U.remove_ansi(text.strip).lines.reject { |l| l.start_with?('TEST_IGN:') }

    unless status.success?
      MB::U.headline "GDB Output"
      STDERR.puts "#{text}"
    end

    expect(lines.count).to eq(3)
    expect(lines[0]).to include('all_notes.mid')
    expect(lines[1]).to match(/49.*C\u266f3.*\u2517\u2501.*\u251b/)
    expect(lines[2]).to match(/48.*C3.*\u2517\u2501.*\u251b/)
  end

  it 'does not allow specifying both -e and -d' do
    text = `bin/midi_roll.rb -e 3 -d 2 2>&1`
    expect($?).not_to be_success

    expect(text).to match(/duration.*both/)
  end
end
