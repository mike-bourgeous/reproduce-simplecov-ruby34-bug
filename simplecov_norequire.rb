require 'simplecov'

SimpleCov.start do
  SimpleCov.command_name "#{$0} #{$$} #{Random.random_number}"
  SimpleCov.formatter SimpleCov::Formatter::SimpleFormatter
  SimpleCov.minimum_coverage 0
end
