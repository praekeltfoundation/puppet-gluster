RSpec::Matchers.define :have_logged do |*expected|
  # TODO: Better negative matching if and when it's necessary.

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
    @unmatched = expected.find do |val, level=nil|
      actual = logs.select { |log| level.nil? or log.level == level }
      actual.none? { |log| values_match?(val, log.message) }
    end
    @unmatched.nil?
  end

  failure_message do |_|
    if @unmatched.is_a? Array
      "no logged #{@unmatched[1]} messages match #{@unmatched[0].inspect}"
    else
      "no logged messages match #{@unmatched.inspect}"
    end
  end

  supports_block_expectations
end
