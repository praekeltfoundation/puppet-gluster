require 'puppetlabs_spec_helper/module_spec_helper'

require 'rspec-puppet-facts'
include RspecPuppetFacts

module RSpecAndMochaAdapter
  # puppetlabs_spec_helper uses mocha all over the place, but mocha only
  # supports static stubs. We need something that will let us invoke our own
  # replacement methods.

  require 'rspec/core/mocking_adapters/rspec'
  require 'rspec/core/mocking_adapters/mocha'

  # These both pull in their own methods, which we need to have available. We
  # include the rspec mocking stuff first so that mocha's methods win if
  # there's a conflict. Hopefully they don't step on each other's toes. :-/
  include ::RSpec::Core::MockingAdapters::RSpec
  alias_method :_rspec_setup_mocks_for_rspec, :setup_mocks_for_rspec
  alias_method :_rspec_verify_mocks_for_rspec, :verify_mocks_for_rspec
  alias_method :_rspec_teardown_mocks_for_rspec, :teardown_mocks_for_rspec

  include ::RSpec::Core::MockingAdapters::Mocha
  alias_method :_mocha_setup_mocks_for_rspec, :setup_mocks_for_rspec
  alias_method :_mocha_verify_mocks_for_rspec, :verify_mocks_for_rspec
  alias_method :_mocha_teardown_mocks_for_rspec, :teardown_mocks_for_rspec

  def setup_mocks_for_rspec
    _rspec_setup_mocks_for_rspec
    _mocha_setup_mocks_for_rspec
  end

  def verify_mocks_for_rspec
    _rspec_verify_mocks_for_rspec
    _mocha_verify_mocks_for_rspec
  end

  def teardown_mocks_for_rspec
    _rspec_teardown_mocks_for_rspec
    _mocha_teardown_mocks_for_rspec
  end
end

RSpec.configure do |config|
  config.mock_with RSpecAndMochaAdapter
end
