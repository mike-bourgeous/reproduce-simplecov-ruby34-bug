#!/usr/bin/env -S ruby -r./ruby34_bug_helper

raise "\e[0;33mThe helper is missing -- run \e[0;1mRUBYOPT=-r$PWD/ruby34_bug_helper.rb #{$0}\e[0m" unless $helper

puts 'This is the script.  It now ends.'
