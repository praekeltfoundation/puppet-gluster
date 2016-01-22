require 'spec_helper'
require 'unit/provider/helpers'

describe Puppet::Type.type(:gluster_peer).provider(:gluster_peer) do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      before :each do
        Facter.clear
        facts.each do |k, v|
          Facter.stubs(:fact).with(k).returns Facter.add(k) { setcode { v } }
        end
      end

      describe 'class methods' do
        [:instances, :prefetch, :all_peers].each do |method|
          it "should have method named #{method}" do
            expect(described_class).to respond_to method
          end
        end
      end

      context 'without peers' do
        before :each do
          described_class.expects(:gluster).with(
            'peer', 'status', '--xml',
          ).returns peer_status_xml([])
        end

        it 'should return no resources' do
          expect(props(described_class.instances)).to eq([])
        end
      end

      context 'with one peer' do
        before :each do
          described_class.expects(:gluster).with(
            'peer', 'status', '--xml',
          ).returns peer_status_xml(['gfs1.local'])
        end

        it 'should return one resource' do
          expect(props(described_class.instances)).to eq([{
                :name => 'gfs1.local',
                :peer => 'gfs1.local',
                :ensure => :present,
              }])
        end
      end

      context 'with two peers' do
        before :each do
          described_class.expects(:gluster).with(
            'peer', 'status', '--xml',
          ).returns peer_status_xml(['gfs1.local', 'gfs2.local'])
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
