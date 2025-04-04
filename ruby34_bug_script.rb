#!/usr/bin/env -S ruby -r./ruby34_bug_helper
# Inner script for reproducing https://github.com/mike-bourgeous/mb-sound/issues/36

raise "\e[0;33mThe helper is missing -- run \e[0;1m./ruby34_bug_wrapper.rb\e[0m" unless $ruby34_bug_helper

puts 'This is the script.  It now ends.'
