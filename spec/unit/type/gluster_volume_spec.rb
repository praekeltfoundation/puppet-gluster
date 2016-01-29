require 'spec_helper'

describe Puppet::Type.type(:gluster_volume) do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      before :each do
        Facter.clear
        facts.each do |k, v|
          Facter.stubs(:fact).with(k).returns Facter.add(k) { setcode { v } }
        end
      end

      describe 'when validating attributes' do
        [ :name, :force, :replica, :bricks ].each do |param|
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
        it "should have :name as its namevar" do
          expect(described_class.key_attributes).to eq([:name])
        end
      end

      describe 'when validating attribute values' do
        describe 'name' do
          it "should accept a string" do
            expect(
              described_class.new(:name => 'data1')
            ).to satisfy { |v| v[:name] == 'data1' }
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

          it "should not accept other values" do
            expect {
              described_class.new(:name => 'data1', :force => 'Yoda')
            }.to raise_error(Puppet::Error, /Invalid value/)
          end
        end

        describe 'replica' do
          it "should accept an empty value" do
            expect(
              described_class.new(:name => 'data1')
            ).to satisfy { |v| v[:replica].nil? }
          end

          it "should accept an integer >= 2" do
            expect(
              described_class.new(:name => 'data1', :replica => 2)
            ).to satisfy { |v| v[:replica] == 2 }
            expect(
              described_class.new(:name => 'data1', :replica => '2')
            ).to satisfy { |v| v[:replica] == 2 }
            expect(
              described_class.new(:name => 'data1', :replica => '17')
            ).to satisfy { |v| v[:replica] == 17 }
          end

          it "should not accept an integer < 2" do
            expect {
              described_class.new(:name => 'data1', :replica => 1)
            }.to raise_error(Puppet::Error, /must be an integer >= 2/)
          end

          it "should not accept an arbitrary string" do
            expect {
              described_class.new(:name => 'data1', :replica => 'seventeen')
            }.to raise_error(Puppet::Error, /must be an integer >= 2/)
          end
        end

        describe 'bricks' do
          it "should default to an empty array" do
            expect(
              described_class.new(:name => 'data1')
            ).to satisfy { |v| v[:bricks] == [] }
          end

          it "should accept a single string" do
            expect(
              described_class.new(:name => 'data1', :bricks => 'p1:b1')
            ).to satisfy { |v| v[:bricks] == ['p1:b1'] }
          end

          it "should accept an array containing a single string" do
            expect(
              described_class.new(:name => 'data1', :bricks => ['p1:b1'])
            ).to satisfy { |v| v[:bricks] == ['p1:b1'] }
          end

          it "should accept an array containing many strings" do
            expect(
              described_class.new(
              :name => 'data1', :bricks => ['p1:b1', 'p2:b1'])
            ).to satisfy { |v| v[:bricks] == ['p1:b1', 'p2:b1'] }
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

          it "should not accept other values" do
            expect { described_class.new(
              :name => 'foo',
              :ensure => 'unhappy',
            )}.to raise_error(Puppet::Error, /Invalid value/)
          end
        end

        describe 'autorequire' do
          before(:each) do
            def vol(*bricks)
              described_class.new(
                :name => 'foo',
                :ensure => :present,
                :bricks => bricks,
              )
            end
            @cat = Puppet::Resource::Catalog.new
          end

          it 'should require Service[glusterfs-server] if declared' do
            @cat.create_resource(:service, :title => 'glusterfs-server')
            expect(
              vol().autorequire(@cat).map { |r| r.source.to_s }
            ).to eq(["Service[glusterfs-server]"])
          end

          it 'should not require Service[glusterfs-server] unless declared' do
            expect(
              vol().autorequire(@cat).map { |r| r.source.to_s }
            ).to eq([])
          end

          it 'should require any brick peers that are declared' do
            @cat.create_resource(:gluster_peer, :title => 'p1')
            @cat.create_resource(:gluster_peer, :title => 'p2')
            @cat.create_resource(:gluster_peer, :title => 'p4')
            expect(vol('p1:/b', 'p2:/b', 'p3:/b').autorequire(@cat).map { |r|
                r.source.to_s
              }).to eq(["Gluster_peer[p1]", "Gluster_peer[p2]"])
          end
        end
      end
    end
  end
end
