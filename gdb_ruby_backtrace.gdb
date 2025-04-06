# GDB script to run a Ruby process and print backtraces for each thread.


# Display colors
set style enabled on

set debuginfod enabled on

define headline
	printf "\n\e[%sm%s\e[0m\n", $arg0, $arg1
	printf "\e[%sm===================\e[0m\n\n", $arg0
end

set $_exitcode = 42

run

if $_exitcode == 0
	printf "\e[1;32mProgram ran without crashing!\e[0m\n"
	exit 0
end

headline "35" "C thread list"
info threads

headline "33" "C backtraces"

# Google Search AI generated this code and I can't find a good reference otherwise
python
num_threads = len(gdb.selected_inferior().threads())
gdb.execute(f"set $num_threads = {num_threads}")
end

set $i = 1
while $i <= $num_threads
	printf "\n\e[33m---> C thread \e[1m%d\e[22m <---\e[0m\n", $i
	thread $i
	backtrace
	set $i = $i + 1
end

thread 1

headline "1;34" "Ruby current thread backtrace"
call rb_backtrace()

# FIXME: find a way to generate these backtraces without allocating memory in the Ruby VM
# headline "1;36" "Ruby per-thread backtraces \e[33m(FIXME: will crash Ruby due to allocating from within GC)"

# Reference: https://www.aha.io/engineering/articles/debugging-ruby-the-hard-way
# Ruby crashes here since the bug we're chasing occurs during GC, and
# rb_thread_list allocates a new array.
# set $thread_list = rb_thread_list()
# set $num_threads = rb_num2long(rb_ary_length($thread_list)

# set $i = 0

# while $i < $num_threads
# 	printf "\n-> \e[36mRuby thread \e[1m%d\e[0m\n", $i
# 	call rb_p(rb_thread_backtrace_m(0, 0, rb_ary_entry($thread_list, $i)))
# 	set $i = $i + 1
# end

printf "\n\n\nDone debugging\n\n\n"

exit 1
