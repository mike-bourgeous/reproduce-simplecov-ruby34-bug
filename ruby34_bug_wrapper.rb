#!/usr/bin/env ruby
# Outer wrapper for reproducing https://github.com/mike-bourgeous/mb-sound/issues/36
# The hypothesis is that SimpleCov must be run from both a parent and child
# process.

require 'simplecov'
SimpleCov.start

puts 'The wrapper has started SimpleCov and will now call the script.'

ENV['RUBYOPT'] = "-r#{File.join(__dir__, 'ruby34_bug_helper.rb')} #{ENV['RUBYOPT']}"
puts "  Using RUBYOPT=#{ENV['RUBYOPT'].inspect}"

output = `./ruby34_bug_script.rb`
