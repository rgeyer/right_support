source "http://rubygems.org"
gemspec

# Gems that RightSupport can optionally make use of, but which it does
# not require to be installed. These would be "optional dependencies"
# if gemspecs allowed for them.
group :optional do
  gem 'net-ssh', "~> 2.0"
  gem 'rest-client', "~> 1.6"
  gem 'addressable', "~> 2.2.7"
end

# Gems used during test and development of RightSupport.
group :development do
  gem 'rake', "0.8.7"
  gem 'ruby-debug', ">= 0.10", :platforms=>:ruby_18
  gem 'ruby-debug19', ">= 0.11.6", :platforms=>:ruby_19
  gem 'rdoc', '>= 2.4.2'
  gem 'rspec', "~> 1.3"
  gem 'cucumber', "~> 0.8"
  gem 'flexmock', "~> 0.8"
end
