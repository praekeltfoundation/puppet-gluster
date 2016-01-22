def props(providers)
  # Extract @property_hash from a provider instance or list thereof.
  if providers.is_a? Puppet::Provider
    providers.instance_variable_get('@property_hash')
  else
    providers.map { |p| props(p) }
  end
end

module GlusterXML
  require 'rexml/document'

  class CLIBase
    def initialize(name, opRet=0, opErrno=0, opErrstr=nil)
      @doc = REXML::Document.new
      @doc << REXML::XMLDecl.new('1.0', 'UTF-8', 'yes')
      root = @doc.add_element 'cliOutput'
      add_elem_text(root, 'opRet', opRet.to_s)
      add_elem_text(root, 'opErrno', opErrno.to_s)
      add_elem_text(root, 'opErrstr', opErrstr)
      @cmd = root.add_element(name)
    end

    def add_elem_text(parent, name, text=nil)
      elem = parent.add_element name
      elem.add_text text unless text.nil?
      elem
    end

    def to_s
      formatter = REXML::Formatters::Pretty.new
      formatter.compact = true
      output = ""
      formatter.write(@doc, output)
      output
    end
  end

  class PeerStatus < CLIBase
    def initialize(peers)
      super('peerStatus')
      peers.each { |peer| add_peer(peer) }
    end

    def add_peer(peer)
      # Build an appropriate peer hash.
      peer = { :hostname => peer } if peer.is_a? String
      peer[:uuid] ||= GlusterXML::uuidify(peer[:hostname])
      peer[:other_names] ||= []
      peer[:connected] ||= 1
      peer[:state] ||= 3
      peer[:stateStr] ||= 'Peer in Cluster'
      # Build the XML for the peer.
      elem = @cmd.add_element('peer')
      add_elem_text(elem, 'uuid', peer[:uuid])
      add_elem_text(elem, 'hostname', peer[:hostname])
      hostnames = elem.add_element('hostnames')
      ([peer[:hostname]] + peer[:other_names]).each do |hostname|
        add_elem_text(hostnames, 'hostname', hostname)
      end
      add_elem_text(elem, 'connected', peer[:connected].to_s)
      add_elem_text(elem, 'state', peer[:state].to_s)
      add_elem_text(elem, 'stateStr', peer[:stateStr])
    end
  end

  def self.uuidify(str)
    # This fakes a UUID by reformatting the MD5 hash of the input.
    Digest::MD5.hexdigest(str).unpack('a8a4a4a4a12').join('-')
  end
end

def peer_status_xml(peers)
  GlusterXML::PeerStatus.new(peers).to_s
end
