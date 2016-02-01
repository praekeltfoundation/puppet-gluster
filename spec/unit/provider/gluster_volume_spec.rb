require 'spec_helper'
require 'unit/helpers'

volume_type = Puppet::Type.type(:gluster_volume)

describe volume_type.provider(:gluster_volume), :unit => true do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      before :each do
        stub_facts(facts)
        @fake_gluster = stub_gluster(described_class)
      end

      describe 'class methods' do
        [:instances, :prefetch, :peers_present, :all_volumes].each do |method|
          it "should have method named #{method}" do
            expect(described_class).to respond_to method
          end
        end
      end

      context 'without volumes' do
        it 'should return no resources' do
          expect(props(described_class.instances)).to eq([])
        end
      end

      context 'with one volume' do
        before :each do
          @fake_gluster.add_volumes({
              :name => 'vol1',
              :replica => 2,
              :bricks => [
                { :name => 'gfs1.local:/b1/vol1' },
                { :name => 'gfs2.local:/b1/vol1' },
              ]
            })
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
          @fake_gluster.add_volumes({
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
            })
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
