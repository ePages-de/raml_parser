require "bundler/gem_tasks"

multitask :default => [:test]
task :spec => :test

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:test)
