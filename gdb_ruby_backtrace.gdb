# GDB script to run a Ruby process and print backtraces for each thread.
# 
run

echo

printf "\n\e[35mC thread list\e[0m\n"
info threads

printf "\n\e[33mC backtraces\e[0m\n"

# Google Search AI generated this code and I can't find a good reference otherwise
python
num_threads = len(gdb.selected_inferior().threads())
gdb.execute(f"set $num_threads = {num_threads}")
end

set $i = 1
while $i <= $num_threads
	printf "\n\e[33m-> C thread \e[1m%d\e[0m\n", $i
	thread $i
	backtrace
	set $i = $i - 1
end

thread 1

printf "\n\e[1;34mRuby backtrace\e[0m\n"
call rb_backtrace()

printf "\n\e[1;36mRuby per-thread backtraces \e[33m(may crash Ruby)\e[0m\n"

# Reference: https://www.aha.io/engineering/articles/debugging-ruby-the-hard-way
set $thread_list = rb_thread_list()
set $num_threads = rb_num2long(rb_ary_length(rb_thread_list())
set $i = 0

while $i < $num_threads
	printf "\n-> \e[36mRuby thread \e[1m%d\e[0m\n", $i
	call rb_p(rb_thread_backtrace_m(0, 0, rb_ary_entry($thread_list, $i++)))
end

printf "\n\n\nDone debugging\n\n\n"

exit 1
