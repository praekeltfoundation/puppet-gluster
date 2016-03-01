source 'https://rubygems.org'

group :test do
  gem 'rake'
  gem 'simplecov'

  puppetversion = ENV.key?('PUPPET_VERSION') ? "#{ENV['PUPPET_VERSION']}" : ['>= 3.4.0']
  gem 'puppet', puppetversion

  gem 'librarian-puppet'
  gem 'metadata-json-lint'
  gem 'puppetlabs_spec_helper', '~> 1.1.0'
  gem 'rspec-puppet-facts'
end
