def props(providers)
  # Extract @property_hash from a provider instance or list thereof.
  if providers.is_a? Puppet::Provider
    providers.instance_variable_get('@property_hash')
  else
    providers.map { |p| props(p) }
  end
end
