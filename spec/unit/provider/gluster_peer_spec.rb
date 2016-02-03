require 'spec_helper'
require 'unit/helpers'

peer_type = Puppet::Type.type(:gluster_peer)

describe peer_type.provider(:gluster_peer), :unit => true do
  before :all do
    # If we've run integration tests before this, we'll already have a default
    # provider that will break our prefetch tests. Calling `unprovide` has the
    # side effect of actually deleting the provider class, which breaks our
    # coverage measurement. To avoid this, we call unprovide once before
    # running these unit tests instead of calling it after running the
    # integration tests. Yay puppet.
    described_class.resource_type.unprovide(:gluster_peer)
  end

  on_supported_os.each do |os, facts|
    context "on #{os}" do
      before :each do
        stub_facts(facts)
        @fake_gluster = stub_gluster(described_class)
        @peer_type = described_class.resource_type
      end

      describe 'class methods' do
        [:instances, :prefetch, :all_peers].each do |method|
          it "should have method named #{method}" do
            expect(described_class).to respond_to method
          end
        end
      end

      context 'without peers' do
        it 'should return no resources' do
          expect(props(described_class.instances)).to eq([])
        end

        it 'should prefetch no providers' do
          res = [1, 2, 3].map { |n| @peer_type.new(:name => "gfs#{n}.local") }
          expect(res_providers(res)).to eq([nil, nil, nil])
          described_class.prefetch(res_hash(res))
          expect(res_providers(res)).to eq([nil, nil, nil])
        end

        describe 'a new peer' do
          before :each do
            @new_peer = described_class.new(
              @peer_type.new(:name => 'new1.local'))
          end

          it 'should not exist' do
            expect(@new_peer.exists?).to eq(false)
          end

          it 'should be created' do
            expect(@fake_gluster.peer_hosts).to eq([])
            @new_peer.create
            expect(@fake_gluster.peer_hosts).to eq(['new1.local'])
            expect(@new_peer.exists?).to eq(true)
          end
        end
      end

      context 'with one peer' do
        before :each do
          @fake_gluster.add_peers('gfs1.local')
        end
        it 'should return one resource' do
          expect(props(described_class.instances)).to eq([{
                :name => 'gfs1.local',
                :peer => 'gfs1.local',
                :ensure => :present,
              }])
        end

        it 'should prefetch one provider' do
          res = [1, 2, 3].map { |n| @peer_type.new(:name => "gfs#{n}.local") }
          expect(res_providers(res)).to eq([nil, nil, nil])
          described_class.prefetch(res_hash(res))
          expect(res_providers(res)).to eq(['gfs1.local', nil, nil])
        end

        describe 'a new peer' do
          before :each do
            @new_peer = described_class.new(
              @peer_type.new(:name => 'new2.local'))
          end

          it 'should not exist' do
            expect(@new_peer.exists?).to eq(false)
          end

          it 'should be created' do
            expect(@fake_gluster.peer_hosts).to eq(['gfs1.local'])
            @new_peer.create
            expect(@fake_gluster.peer_hosts).to eq(['gfs1.local', 'new2.local'])
            expect(@new_peer.exists?).to eq(true)
          end
        end

        describe 'an existing peer' do
          before :each do
            (@peer,) = described_class.instances
            @peer.resource = @peer_type.new(
              :name => 'gfs1.local', :ensure => :present)
          end

          it 'should exist' do
            expect(@peer.exists?).to eq(true)
          end

          it 'should be destroyed' do
            expect(@fake_gluster.peer_hosts).to eq(['gfs1.local'])
            @peer.destroy
            expect(@fake_gluster.peer_hosts).to eq([])
            expect(@peer.exists?).to eq(false)
          end
        end
      end

      context 'with two peers' do
        before :each do
          @fake_gluster.add_peers(['gfs1.local', 'gfs2.local'])
        end
        it 'should return two resources' do
          expect(props(described_class.instances)).to eq([{
                :name => 'gfs1.local',
                :peer => 'gfs1.local',
                :ensure => :present,
              }, {
                :name => 'gfs2.local',
                :peer => 'gfs2.local',
                :ensure => :present,
              }])
        end

        it 'should prefetch two providers' do
          res = [1, 2, 3].map { |n| @peer_type.new(:name => "gfs#{n}.local") }
          expect(res_providers(res)).to eq([nil, nil, nil])
          described_class.prefetch(res_hash(res))
          expect(res_providers(res)).to eq(['gfs1.local', 'gfs2.local', nil])
        end
      end

      describe 'edge cases' do
        before :each do
          @unreachable_peer = described_class.new(
            @peer_type.new(:name => 'unreachable.local'))
        end

        it 'should not explode if a peer is unreachable (old msg)' do
          @fake_gluster.peer_unreachable(
            'unreachable.local', 'Probe returned with unknown errno 107')
          expect(@fake_gluster.peer_hosts).to eq([])
          expect { @unreachable_peer.create }.to have_logged(
            [/not actually creating.*unknown errno 107/, :warning])
          expect(@fake_gluster.peer_hosts).to eq([])
        end

        it 'should not explode if a peer is unreachable (new msg)' do
          @fake_gluster.peer_unreachable(
            'unreachable.local',
            'Probe returned with Transport endpoint is not connected')
          expect(@fake_gluster.peer_hosts).to eq([])
          expect { @unreachable_peer.create }.to have_logged(
            [/not actually creating.*Transport endpoint is not/, :warning])
          expect(@fake_gluster.peer_hosts).to eq([])
        end

        it 'should fail on an unexpected error' do
          @fake_gluster.set_error(-1, 2, 'A bad thing happened.')
          expect { @unreachable_peer.create }.to raise_error(GlusterCmdError)
        end
      end

    end
  end
end
