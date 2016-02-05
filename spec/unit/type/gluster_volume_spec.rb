require 'spec_helper'

describe Puppet::Type.type(:gluster_volume), :unit => true do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      before :each do
        stub_facts(facts)
      end

      describe 'when validating attributes' do
        [:name, :force, :replica, :bricks, :local_peer_aliases].each do |param|
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

      describe 'namevar validation' do
        it 'should have :name as its namevar' do
          expect(described_class.key_attributes).to eq([:name])
        end
      end

      describe 'when validating attribute values' do
        describe 'name' do
          it 'should accept a string' do
            expect(described_class.new(:name => 'data1')[:name]).to eq('data1')
          end
        end

        describe 'force' do
          [true, false].each do |value|
            it "should accept #{value}" do
              expect(
                described_class.new(:name => 'data1', :force => value)
              ).to satisfy { |v| v[:force] == value and !!v.force? == value }
            end
          end

          it 'should not accept other values' do
            expect {
              described_class.new(:name => 'data1', :force => 'Yoda')
            }.to raise_error(Puppet::Error, /Invalid value/)
          end
        end

        describe 'replica' do
          it 'should accept an empty value' do
            expect(described_class.new(:name => 'data1')[:replica]).to be_nil
          end

          it 'should accept an integer >= 2' do
            expect(
              described_class.new(:name => 'data1', :replica => 2)[:replica]
            ).to eq(2)
            expect(
              described_class.new(:name => 'data1', :replica => '2')[:replica]
            ).to eq(2)
            expect(
              described_class.new(:name => 'data1', :replica => '17')[:replica]
            ).to eq(17)
          end

          it 'should not accept an integer < 2' do
            expect {
              described_class.new(:name => 'data1', :replica => 1)
            }.to raise_error(Puppet::Error, /must be an integer >= 2/)
          end

          it 'should not accept an arbitrary string' do
            expect {
              described_class.new(:name => 'data1', :replica => 'seventeen')
            }.to raise_error(Puppet::Error, /must be an integer >= 2/)
          end
        end

        describe 'bricks' do
          it 'should default to an empty array' do
            expect(described_class.new(:name => 'data1')[:bricks]).to eq([])
          end

          it 'should accept a single string' do
            expect(described_class.new(
                :name => 'data1', :bricks => 'p1:b1')[:bricks]
            ).to eq(['p1:b1'])
          end

          it 'should accept an array containing a single string' do
            expect(described_class.new(
                :name => 'data1', :bricks => ['p1:b1'])[:bricks]
            ).to eq(['p1:b1'])
          end

          it 'should accept an array containing many strings' do
            expect(described_class.new(
                :name => 'data1', :bricks => ['p1:b1', 'p2:b1'])[:bricks]
            ).to eq(['p1:b1', 'p2:b1'])
          end
        end

        describe 'local_peer_aliases' do
          # FIXME: This should test the missing fact handling, but it seems
          # really hard to get rid of the facts.

          default_aliases = facts.values_at(:fqdn, :hostname, :ipaddress)

          def lpa_of_new(args={})
            described_class.new(args)[:local_peer_aliases]
          end

          it 'should include default values' do
            expect(
              lpa_of_new(:name => 'foo')
            ).to contain_exactly(*default_aliases)
          end

          it 'should accept a single string' do
            expect(
              lpa_of_new(:name => 'foo', :local_peer_aliases => 'foo')
            ).to contain_exactly('foo', *default_aliases)
          end

          it 'should accept an array containing a single string' do
            expect(
              lpa_of_new(:name => 'foo', :local_peer_aliases => ['foo'])
            ).to contain_exactly('foo', *default_aliases)
          end

          it 'should accept an array containing many strings' do
            expect(
              lpa_of_new(:name => 'foo', :local_peer_aliases => ['a', 'b'])
            ).to contain_exactly('a', 'b', *default_aliases)
          end
        end

        describe 'ensure' do
          [ :present, :absent, :stopped ].each do |value|
            it "should accept #{value}" do
              expect {described_class.new(
                :name => 'foo',
                :ensure => value,
              )}.to_not raise_error
            end
          end

          it 'should not accept other values' do
            expect { described_class.new(
              :name => 'foo',
              :ensure => 'unhappy',
            )}.to raise_error(Puppet::Error, /Invalid value/)
          end
        end

        describe 'autorequire' do
          before :each do
            @cat = Puppet::Resource::Catalog.new
          end

          def autoreq_vol(*bricks)
            described_class.new(
              :name => 'foo',
              :ensure => :present,
              :bricks => bricks,
            ).autorequire(@cat).map { |r| r.source.to_s }
          end

          it 'should require Service[glusterfs-server] if declared' do
            @cat.create_resource(:service, :title => 'glusterfs-server')
            expect(autoreq_vol).to eq(['Service[glusterfs-server]'])
          end

          it 'should require Package[glusterfs-server] if declared' do
            @cat.create_resource(:package, :title => 'glusterfs-server')
            expect(autoreq_vol).to eq(['Package[glusterfs-server]'])
          end

          it 'should not require package or service unless declared' do
            expect(autoreq_vol).to eq([])
          end

          it 'should require any brick peers that are declared' do
            @cat.create_resource(:gluster_peer, :title => 'p1')
            @cat.create_resource(:gluster_peer, :title => 'p2')
            @cat.create_resource(:gluster_peer, :title => 'p4')
            expect(
              autoreq_vol('p1:/b', 'p2:/b', 'p3:/b')
            ).to contain_exactly('Gluster_peer[p1]', 'Gluster_peer[p2]')
          end
        end

        describe 'ensure behaviour' do
          before :each do
            # This needs to be a subclass of Puppet::Provider, so we can't use
            # a double.
            class FakeProv < Puppet::Provider
            end
            @prov = FakeProv.new
            @res = described_class.new(:name => 'volname')
            @res.provider = @prov
          end

          it 'should retrieve the correct state' do
            allow(@prov).to receive(:get).with(:ensure).and_return(:present)
            expect(@res.property(:ensure).retrieve).to eq(:present)
            allow(@prov).to receive(:get).with(:ensure).and_return(:absent)
            expect(@res.property(:ensure).retrieve).to eq(:absent)
            allow(@prov).to receive(:get).with(:ensure).and_return(:stopped)
            expect(@res.property(:ensure).retrieve).to eq(:stopped)
          end

          it 'should create when necessary' do
            @res[:ensure] = :present
            expect(@prov).to receive(:create).twice
            allow(@prov).to receive(:get).with(:ensure).and_return(:absent)
            expect { @res.property(:ensure).sync }.to_not raise_error
            allow(@prov).to receive(:get).with(:ensure).and_return(:stopped)
            expect { @res.property(:ensure).sync }.to_not raise_error
          end

          it 'should destroy when necessary' do
            @res[:ensure] = :absent
            expect(@prov).to receive(:destroy).twice
            allow(@prov).to receive(:get).with(:ensure).and_return(:present)
            expect { @res.property(:ensure).sync }.to_not raise_error
            allow(@prov).to receive(:get).with(:ensure).and_return(:stopped)
            expect { @res.property(:ensure).sync }.to_not raise_error
          end

          it 'should ensure_stopped when necessary' do
            @res[:ensure] = :stopped
            expect(@prov).to receive(:ensure_stopped).twice
            allow(@prov).to receive(:get).with(:ensure).and_return(:present)
            expect { @res.property(:ensure).sync }.to_not raise_error
            allow(@prov).to receive(:get).with(:ensure).and_return(:absent)
            expect { @res.property(:ensure).sync }.to_not raise_error
          end

          it 'should create if no peers are missing' do
            @res[:bricks] = [1, 2, 3].map { |n| "gfs#{n}.local:/b1/v1" }
            allow(@prov).to receive(:missing_peers).and_return([])
            expect(@res.property(:ensure).insync? :absent).to eq(false)
            expect(@res.property(:ensure).insync? :present).to eq(true)
          end

          it 'should not create if a peer is missing' do
            @res[:bricks] = [1, 2, 3].map { |n| "gfs#{n}.local:/b1/v1" }
            allow(@prov).to receive(:missing_peers).and_return(
              ['gfs1.local', 'gfs3.local'])
            expect {
              expect(@res.property(:ensure).insync? :absent).to eq(true)
            }.to have_logged(
              # All of these are the same line, but it's simpler to match them
              # separately.
              [/Ignoring.*volname.*pretending it's present/, :info],
              [/gfs1\.local/, :info],
              [/gfs3\.local/, :info],
            )
            expect(@res.property(:ensure).insync? :present).to eq(true)
          end
        end

      end
    end
  end
end
