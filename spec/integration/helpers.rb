def apply_manifest(manifest_text)
  # Applies the given manifest in as safe a manner as possible.
  # Note: This will try (and fail) to create files, etc.
  Puppet[:code] = manifest_text
  node = Puppet::Node.indirection.find(Facter.value(:fqdn))
  catalog = Puppet::Resource::Catalog.indirection.find(
    node.name, :use_node => node)
  catalog = catalog.to_ral
  catalog.finalize
  # If we're a host_config (the default), puppet tries to store stuff.
  catalog.instance_variable_set(:@host_config, false)
  catalog.apply
end

def unconfine(provider_class, confine_values)
  # Provider suitability is decided by checking the "confines" on the provider
  # class. Our test environment might not meet all the declared conditions for
  # suitability (if we're faking a missing command, for example) so this method
  # digs aroung in puppet's internals to remove confinements we don't want.
  col = provider_class.instance_variable_get('@confine_collection')
  col.instance_variable_get('@confines').delete_if do |c|
    c.values == confine_values
  end
end
