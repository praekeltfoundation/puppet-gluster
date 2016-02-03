RSpec::Matchers.define :have_logged do |*expected|
  def call_and_collect(&block)
    logs = []
    destination = Puppet::Test::LogCollector.new(logs)
    old_level = Puppet::Util::Log.level
    Puppet::Util::Log.level = :debug
    begin
      Puppet::Util::Log.with_destination(destination, &block)
    ensure
      Puppet::Util::Log.level = old_level
    end
    logs
  end

  match do |block|
    logs = call_and_collect(&block)
    expected.all? do |val, level=nil|
      actual = logs.select { |log| level.nil? or log.level == level }
      actual.any? { |log| values_match?(val, log.message) }
    end
  end

  supports_block_expectations
end
