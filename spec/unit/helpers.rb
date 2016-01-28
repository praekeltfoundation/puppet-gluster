def props(providers)
  # Extract @property_hash from a provider instance or list thereof.
  if providers.is_a? Puppet::Provider
    providers.instance_variable_get('@property_hash')
  else
    providers.map { |p| props(p) }
  end
end

# To avoid extra requires all over the place.
require 'unit/fake_gluster'
