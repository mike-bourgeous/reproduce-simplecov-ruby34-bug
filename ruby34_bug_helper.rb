# Minimal replication of bug seen with spec/simplecov_helper.rb from mb-sound.
#
# See https://github.com/mike-bourgeous/mb-sound/issues/36

puts 'This is the helper.  It begins.'
$helper=true
require File.expand_path($0, '.')
puts 'The helper shall now depart.'
exit 0
puts 'The helper has remained beyond its welcome.'
