def apply_node_manifest(manifest_text)
  # See `apply_manifest`. This just adds node boilerplate and calls that.
  apply_manifest("node default {\n#{manifest_text}\n}")
end


def apply_manifest(manifest_text)
  # Applies the given manifest in as safe a manner as possible.
  # NOTE: This will try (and fail) to create files, etc.

  # This is reverse-engineered from the `puppet apply --execute` code and turns
  # the manifest text into a compiled catalog.
  Puppet[:code] = manifest_text
  node = Puppet::Node.indirection.find(Facter.value(:fqdn))
  catalog = Puppet::Resource::Catalog.indirection.find(
    node.name, :use_node => node)
  catalog = catalog.to_ral

  apply_catalog(catalog)
end

def apply_catalog_with(*resources)
  # Creates and applies a catalog containing the given resources.
  # NOTE: This will try (and fail) to create files, etc.
  catalog = Puppet::Resource::Catalog.new
  resources.each { |resource| catalog.add_resource(resource) }
  apply_catalog(catalog)
end

def apply_catalog(catalog)
  # We skip all the runtime wrappers and apply the catalog directly because
  # this isn't a real run. We also turn off the `host_config` flag so that
  # puppet doesn't try to load or store state.

  # NOTE: This will try (and fail) to create files, etc.
  catalog.host_config = false
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
