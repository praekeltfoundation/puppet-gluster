require 'rspec/expectations'
require 'rspec-puppet/matchers/create_generic'

# We need `#===` to behave like `#matches?` for `values_match?` to work.
class RSpec::Puppet::ManifestMatchers::CreateGeneric
  alias :=== :matches?
end

RSpec::Matchers.define :have_resource_order do |*expected|
  def make_matchers(resources)
    ms = []
    resources.each_cons(3) do |before, resource, after|
      m = resource.match(/(.*)\[(.*)\]/)
      meth = "contain_#{m[1].downcase}"
      matcher = RSpec::Puppet::ManifestMatchers::CreateGeneric.new(meth, m[2])
      ms << matcher.that_requires(before).that_comes_before(after)
    end
    ms
  end

  match do |actual|
    @unmatched = make_matchers(expected).find do |matcher|
      !values_match?(matcher, actual)
    end
    @unmatched.nil?
  end

  def failure_message
    @unmatched.failure_message
  end
end
