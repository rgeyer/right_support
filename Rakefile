# -*-ruby-*-
require 'rubygems'
require 'bundler/setup'

require 'rake'
require 'rdoc/task'
require 'rubygems/package_task'
require 'rake/clean'
require 'rspec/core/rake_task'
require 'cucumber/rake/task'

desc "Run unit tests"
task :default => :spec

desc "Run unit tests"
RSpec::Core::RakeTask.new do |t|
  t.pattern = Dir['**/*_spec.rb']
end

desc "Run functional tests"
Cucumber::Rake::Task.new do |t|
  t.cucumber_opts = %w{--color --format pretty}
end

desc 'Generate documentation for the right_support gem.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = 'RightSupport'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
  rdoc.rdoc_files.exclude('features/**/*')
  rdoc.rdoc_files.exclude('spec/**/*')
end

desc "Build right_support gem"
Gem::PackageTask.new(Gem::Specification.load("right_support.gemspec")) do |package|
  package.need_zip = true
  package.need_tar = true
end

CLEAN.include('pkg')

namespace :ci do
  desc "Run unit tests"
  RSpec::Core::RakeTask.new do |t|
    t.pattern = Dir['**/*_spec.rb']
    t.rspec_opts = %w{-r spec/junit.rb -f JUnit -o results.xml}
  end

  desc "Run functional tests"
  Cucumber::Rake::Task.new do |t|
    t.cucumber_opts = %w{--color --format pretty}
  end
end