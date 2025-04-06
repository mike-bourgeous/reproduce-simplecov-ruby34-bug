RSpec.describe('bin/midi_roll.rb', :aggregate_failures) do
  it 'can display a MIDI roll' do
    if ENV['INTERACTIVE_GDB'] == '1'
      MB::U.headline 'Starting interactive GDB'
      system("gdb -x ./gdb_ruby_backtrace.gdb --args $(which ruby) bin/midi_roll.rb -r 2 -c 100 -n C3 spec/test_data/all_notes.mid 2>&1")
    end

    if ENV['VALGRIND'] == '1'
      MB::U.headline 'Starting valgrind'
      system("valgrind --undef-value-errors=no -s $(which ruby) bin/midi_roll.rb -r 2 -c 100 -n C3 spec/test_data/all_notes.mid 2>&1")
    end

    # unbuffer is from the expect package and uses a pseudoterminal to make gdb print colors
    text = `unbuffer gdb --batch -x ./gdb_ruby_backtrace.gdb --args $(which ruby) bin/midi_roll.rb -r 2 -c 100 -n C3 spec/test_data/all_notes.mid 2>&1`
    status = $?

    expect(status).to be_success

    unless status.success?
      MB::U.headline "GDB Output"
      puts "#{text}"
    end
  end
end
