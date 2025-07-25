require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

desc "Run tests"
task test: :spec

desc "Build the gem"
task build: :spec do
  system "gem build llms.gemspec"
end

desc "Install the gem locally"
task install: :build do
  system "gem install llms-*.gem"
end

desc "Clean up build artifacts"
task clean: :clobber do
  rm_rf "llms-*.gem"
end 