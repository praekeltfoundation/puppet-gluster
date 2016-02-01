require 'spec_helper'
require 'unit/helpers'

peer_type = Puppet::Type.type(:gluster_peer)

describe peer_type.provider(:gluster_peer), :unit => true do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      before :each do
        stub_facts(facts)
        @fake_gluster = stub_gluster(described_class)
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

        describe 'a new peer' do
          before :each do
            res = described_class.resource_type.new(:name => 'new1.local')
            @new_peer = described_class.new(res)
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

        describe 'a new peer' do
          before :each do
            res = described_class.resource_type.new(:name => 'new2.local')
            @new_peer = described_class.new(res)
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
            @peer.resource = described_class.resource_type.new(
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
      end

    end
  end
end
