module RSpecAndMochaAdapter
  # Wrapper around two mock adapters for rspec. This is horrible, but
  # apparently necessary.

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
