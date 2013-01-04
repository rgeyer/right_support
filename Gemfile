source "http://rubygems.org"
gemspec

# Gems that RightSupport can optionally make use of, but which it does
# not require to be installed. These would be "optional dependencies"
# if gemspecs allowed for them.
group :optional do
  gem 'net-ssh', "~> 2.0"
  gem 'rest-client', "~> 1.6"
  gem 'addressable', "~> 2.2.7"
  gem 'uuidtools', "~> 2.0", :require=>nil
  gem 'simple_uuid', "~> 0.2", :require=>nil
  gem 'uuid', "~> 2.3", :require=>nil
  gem 'yajl-ruby', "~> 1.1"
end

# Gems used during test and development of RightSupport.
group :development do
  gem 'rake', "0.8.7"
  gem 'ruby-debug', ">= 0.10", :platforms=>:ruby_18
  gem 'ruby-debug19', ">= 0.11.6", :platforms=>:ruby_19
  gem 'rdoc', '>= 2.4.2'
  gem 'rspec', "~> 2.0"
  gem 'cucumber', "~> 1.0"
  gem 'flexmock', "~> 0.8"
  gem 'syntax', '~> 1.0.0' #rspec will syntax-highlight code snippets if this gem is available
  gem 'nokogiri', '~> 1.5'
end
