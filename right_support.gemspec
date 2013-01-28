# -*- mode: ruby; encoding: utf-8 -*-

require 'rubygems'

spec = Gem::Specification.new do |s|
  s.required_rubygems_version = nil if s.respond_to? :required_rubygems_version=
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.7")

  s.name    = 'right_support'
  s.version = '2.6.16'
  s.date    = '2013-01-28'

  s.authors = ['Tony Spataro', 'Sergey Sergyenko', 'Ryan Williamson', 'Lee Kirchhoff', 'Sergey Enin', 'Alexey Karpik', 'Scott Messier']
  s.email   = 'support@rightscale.com'
  s.homepage= 'https://github.com/rightscale/right_support'

  s.summary = %q{Reusable foundation code.}
  s.description = %q{A toolkit of useful, reusable foundation code created by RightScale.}

  basedir = File.dirname(__FILE__)
  candidates = ['right_support.gemspec', 'LICENSE', 'README.rdoc'] + Dir['lib/**/*']
  s.files = candidates.sort
end
