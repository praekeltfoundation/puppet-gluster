def props(providers)
  # Extract @property_hash from a provider instance or list thereof.
  if providers.is_a? Puppet::Provider
    providers.instance_variable_get('@property_hash')
  else
    providers.map { |p| props(p) }
  end
end

def res_hash(resources)
  Hash[resources.map { |r| [r.name, r] }]
end

def res_providers(resources)
  resources.map { |r| r.provider && r.provider.name }
end
