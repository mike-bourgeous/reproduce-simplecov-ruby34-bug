# Minimal replication of bug seen with spec/simplecov_helper.rb from mb-sound.
#
# See https://github.com/mike-bourgeous/mb-sound/issues/36

require 'simplecov'

puts 'This is the helper.  It begins.'
$ruby34_bug_helper=true

SimpleCov.start do
  SimpleCov.command_name "#{$0} #{$$} #{Random.random_number}"
  SimpleCov.formatter SimpleCov::Formatter::SimpleFormatter
  SimpleCov.minimum_coverage 0
end

require File.expand_path($0, '.')

puts 'The helper shall now depart.'
exit 0
puts 'The helper has remained beyond its welcome.'
