require 'spec_helper'
require 'unit/provider/helpers'
require 'unit/provider/fake_gluster'

describe Puppet::Type.type(:gluster_volume).provider(:gluster_volume) do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      before :each do
        Facter.clear
        facts.each do |k, v|
          Facter.stubs(:fact).with(k).returns Facter.add(k) { setcode { v } }
        end
      end

      describe 'class methods' do
        [:instances, :prefetch, :peers_present, :all_volumes].each do |method|
          it "should have method named #{method}" do
            expect(described_class).to respond_to method
          end
        end
      end

      context 'without volumes' do
        before :each do
          fake_gluster = FakeGluster.new([], [])
          described_class.expects(:gluster).with(
            'volume', 'info', 'all', '--xml',
          ).returns fake_gluster.volume_info
        end

        it 'should return no resources' do
          expect(props(described_class.instances)).to eq([])
        end
      end

      context 'with one volume' do
        before :each do
          fake_gluster = FakeGluster.new([], [{
                :name => 'vol1',
                :replica => 2,
                :bricks => [
                  { :name => 'gfs1.local:/b1/vol1' },
                  { :name => 'gfs2.local:/b1/vol1' },
                ]
              }])
          described_class.expects(:gluster).with(
            'volume', 'info', 'all', '--xml',
          ).returns fake_gluster.volume_info
        end

        it 'should return one resource' do
          expect(props(described_class.instances)).to eq([{
                :name => 'vol1',
                :ensure => :present,
              }])
        end
      end

      context 'with two volumes' do
        before :each do
          fake_gluster = FakeGluster.new([], [{
                :name => 'vol1',
                :replica => 2,
                :bricks => [
                  { :name => 'gfs1.local:/b1/vol1' },
                  { :name => 'gfs2.local:/b1/vol1' },
                ]
              }, {
                :name => 'vol2',
                :bricks => [
                  { :name => 'gfs1.local:/b1/vol2' },
                  { :name => 'gfs2.local:/b1/vol2' },
                ]
              }])
          described_class.expects(:gluster).with(
            'volume', 'info', 'all', '--xml',
          ).returns fake_gluster.volume_info
        end

        it 'should return two resources' do
          expect(props(described_class.instances)).to eq([{
                :name => 'vol1',
                :ensure => :present,
              }, {
                :name => 'vol2',
                :ensure => :present,
              }])
        end
      end

    end
  end
end
