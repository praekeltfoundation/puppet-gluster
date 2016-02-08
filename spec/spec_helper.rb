require 'simplecov'
SimpleCov.start do
  add_filter '/spec/fixtures/'
end

require 'puppetlabs_spec_helper/module_spec_helper'

require 'rspec-puppet-facts'
include RspecPuppetFacts

# puppetlabs_spec_helper uses mocha all over the place, but mocha only
# supports static stubs. We need something that will let us invoke our own
# replacement methods.
require 'helpers/mock_adapter'
RSpec.configure do |config|
  config.mock_with RSpecAndMochaAdapter
end

# These helpers are useful to have everywhere.
require 'helpers/fake_facts'
require 'helpers/fake_gluster'
require 'helpers/log_matcher'
