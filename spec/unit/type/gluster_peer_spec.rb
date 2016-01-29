require 'spec_helper'

describe Puppet::Type.type(:gluster_peer), :unit => true do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      before :each do
        allow(Facter).to receive(:collection, &make_fake_collection(facts))
        Facter.reset
      end

      # This uses `define_method` so that `facts` is in scope.
      define_method(:get_facts) do |*names|
        names.map { |name| facts[name] }
      end

      describe 'when validating attributes' do
        [ :peer, :ignore_peers ].each do |param|
          it "should have a #{param} parameter" do
            expect(described_class.attrtype(param)).to eq(:param)
          end
        end
        [ :ensure ].each do |prop|
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
              described_class.new(:peer => 'gfs1')
            ).to satisfy { |v| v[:peer] == 'gfs1' }
          end

          it "should accept a fully qualified domain" do
            expect(
              described_class.new(:peer => 'gfs2.example.com')
            ).to satisfy { |v| v[:peer] == 'gfs2.example.com' }
          end

          it "should accept an IP" do
            expect(
              described_class.new(:peer => '1.2.3.4')
            ).to satisfy { |v| v[:peer] == '1.2.3.4' }
          end
        end

        describe 'ignore_peers' do
          # FIXME: This should test the missing fact handling, but it seems
          # really hard to get rid of the facts.

          it "should include default values" do
            default = get_facts(:fqdn, :hostname, :ipaddress, :ipaddress_lo)
            expect(
              described_class.new(:peer => 'foo')
            ).to satisfy { |v| v[:ignore_peers] == default }
          end

          it "should accept a single string" do
            default = get_facts(:fqdn, :hostname, :ipaddress, :ipaddress_lo)
            expect(
              described_class.new(:peer => 'foo', :ignore_peers => 'foo')
            ).to satisfy { |v| v[:ignore_peers] == ['foo'] + default }
          end

          it "should accept an array containing a single string" do
            default = get_facts(:fqdn, :hostname, :ipaddress, :ipaddress_lo)
            expect(
              described_class.new(:peer => 'foo', :ignore_peers => ['foo'])
            ).to satisfy { |v| v[:ignore_peers] == ['foo'] + default }
          end

          it "should accept an array containing many strings" do
            default = get_facts(:fqdn, :hostname, :ipaddress, :ipaddress_lo)
            expect(
              described_class.new(:peer => 'foo', :ignore_peers => ['a', 'b'])
            ).to satisfy { |v| v[:ignore_peers] == ['a', 'b'] + default }
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

        describe 'ignoring peers' do
          it 'should not ignore arbitrary peers' do
            rtype = described_class.new(
              :peer => 'peer.example.com',
              :ensure => :present)
            expect(rtype.parameter(:ensure).insync? :absent).to eq(false)
            expect(rtype.parameter(:ensure).insync? :present).to eq(true)
          end

          it 'should ignore localhost' do
            # We ignore peers by always pretending they're in sync.
            rtype = described_class.new(
              :peer => '127.0.0.1',
              :ensure => :present)
            expect(rtype.parameter(:ensure).insync? :absent).to eq(true)
            expect(rtype.parameter(:ensure).insync? :present).to eq(true)
          end

          it 'should ignore ignored peers' do
            # We ignore peers by always pretending they're in sync.
            rtype = described_class.new(
              :peer => 'peer.example.com',
              :ensure => :present,
              :ignore_peers => ['peer.example.com'])
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

          it 'should not require Service[glusterfs-server] unless declared' do
            expect(
              @rtype.autorequire(@cat).map { |r| r.source.to_s }
            ).to eq([])
          end
        end
      end
    end
  end
end
