# The usual way of stubbing facts is pretty broken. It only accepts symbols
# (but sometimes keys are given), it blows up instead of returning `nil` for
# missing facts, and it doesn't override the other mechanisms available for
# querying facts.
#
# Instead, we swap out the usual fact-loading machinery with our own version
# that injects our fake facts and doesn't leak anything anywhere.

require 'facter/util/nothing_loader'

class FakeFactLoader
  def initialize(facts)
    @facts = facts
  end

  def load(fact)
    if value = @facts[fact]
      Facter.add(fact) { setcode { value } }
    end
  end

  def load_all
    @facts.each { |k, v| load(k) }
  end
end

def stub_facts(facts)
  allow(Facter).to receive(:collection) do
    unless Facter.instance_variable_defined?(:@collection) and
        Facter.instance_variable_get(:@collection)
      Facter.instance_variable_set(
        :@collection, Facter::Util::Collection.new(
          FakeFactLoader.new(facts), Facter::Util::NothingLoader.new))
    end
    Facter.instance_variable_get(:@collection)
  end
  Facter.reset
end
