require 'spec_helper'

describe Puppet::Type.type(:gluster_peer), :unit => true do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      before :each do
        stub_facts(facts)
      end

      describe 'when validating attributes' do
        [:peer, :local_peer_aliases].each do |param|
          it "should have a #{param} parameter" do
            expect(described_class.attrtype(param)).to eq(:param)
          end
        end
        [:ensure].each do |prop|
          it "should have a #{prop} parameter" do
            expect(described_class.attrtype(prop)).to eq(:property)
          end
        end
      end

      describe "namevar validation" do
        it "should have :peer as its namevar" do
          expect(described_class.key_attributes).to eq([:peer])
        end
      end

      describe 'when validating attribute values' do
        describe 'peer' do
          it "should accept a hostname" do
            expect(
              described_class.new(:peer => 'gfs1')[:peer]
            ).to eq('gfs1')
          end

          it "should accept a fully qualified domain" do
            expect(
              described_class.new(:peer => 'gfs2.example.com')[:peer]
            ).to eq('gfs2.example.com')
          end

          it "should accept an IP" do
            expect(
              described_class.new(:peer => '1.2.3.4')[:peer]
            ).to eq('1.2.3.4')
          end
        end

        describe 'local_peer_aliases' do
          # FIXME: This should test the missing fact handling, but it seems
          # really hard to get rid of the facts.

          default_aliases = facts.values_at(:fqdn, :hostname, :ipaddress)

          def lpa_of_new(args={})
            described_class.new(args)[:local_peer_aliases]
          end

          it "should include default values" do
            expect(
              lpa_of_new(:peer => 'foo')
            ).to contain_exactly(*default_aliases)
          end

          it "should accept a single string" do
            expect(
              lpa_of_new(:peer => 'foo', :local_peer_aliases => 'foo')
            ).to contain_exactly('foo', *default_aliases)
          end

          it "should accept an array containing a single string" do
            expect(
              lpa_of_new(:peer => 'foo', :local_peer_aliases => ['foo'])
            ).to contain_exactly('foo', *default_aliases)
          end

          it "should accept an array containing many strings" do
            expect(
              lpa_of_new(:peer => 'foo', :local_peer_aliases => ['a', 'b'])
            ).to contain_exactly('a', 'b', *default_aliases)
          end
        end

        describe 'ensure' do
          [ :present, :absent ].each do |value|
            it "should accept #{value}" do
              expect { described_class.new(
                :peer => 'peer.example.com',
                :ensure => value,
              )}.to_not raise_error
            end
          end

          it "should not accept other values" do
            expect { described_class.new(
              :peer => 'peer.example.com',
              :ensure => 'unhappy',
            )}.to raise_error(Puppet::Error, /Invalid value/)
          end
        end

        describe 'local peer aliases' do
          it 'should not ignore arbitrary peers' do
            rtype = described_class.new(
              :peer => 'peer.example.com',
              :ensure => :present)
            expect(rtype.parameter(:ensure).insync? :absent).to eq(false)
            expect(rtype.parameter(:ensure).insync? :present).to eq(true)
          end

          it 'should ignore the local host' do
            # We ignore peers by always pretending they're in sync.
            rtype = described_class.new(
              :peer => Facter.value(:fqdn),
              :ensure => :present)
            expect(rtype.parameter(:ensure).insync? :absent).to eq(true)
            expect(rtype.parameter(:ensure).insync? :present).to eq(true)
          end

          it 'should ignore local peer aliases' do
            # We ignore peers by always pretending they're in sync.
            rtype = described_class.new(
              :peer => 'peer.example.com',
              :ensure => :present,
              :local_peer_aliases => ['peer.example.com'])
            expect(rtype.parameter(:ensure).insync? :absent).to eq(true)
            expect(rtype.parameter(:ensure).insync? :present).to eq(true)
          end
        end

        describe 'autorequire' do
          before :each do
            @rtype = described_class.new(
              :peer => 'peer.example.com',
              :ensure => :present)
            @cat = Puppet::Resource::Catalog.new
          end

          it 'should require Service[glusterfs-server] if declared' do
            @cat.create_resource(:service, :title => 'glusterfs-server')
            expect(
              @rtype.autorequire(@cat).map { |r| r.source.to_s }
            ).to eq(["Service[glusterfs-server]"])
          end

          it 'should require Package[glusterfs-server] if declared' do
            @cat.create_resource(:package, :title => 'glusterfs-server')
            expect(
              @rtype.autorequire(@cat).map { |r| r.source.to_s }
            ).to eq(["Package[glusterfs-server]"])
          end

          it 'should not require package or service unless declared' do
            expect(
              @rtype.autorequire(@cat).map { |r| r.source.to_s }
            ).to eq([])
          end
        end
      end
    end
  end
end
