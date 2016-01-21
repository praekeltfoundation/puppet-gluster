require 'spec_helper'

describe Puppet::Type.type(:gluster_peer) do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      before :each do
        Facter.clear
        facts.each do |k, v|
          Facter.stubs(:fact).with(k).returns Facter.add(k) { setcode { v} }
        end
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

        # :peer

        # :ignore_peers

        describe 'ensure' do
          [ :present, :absent ].each do |value|
            it "should support #{value} as a value to ensure" do
              expect { described_class.new(
                :peer => 'peer.example.com',
                :ensure => value,
              )}.to_not raise_error
            end
          end
        end

        it "should not support other values" do
          expect { described_class.new(
            :peer => 'peer.example.com',
            :ensure => 'unhappy',
          )}.to raise_error(Puppet::Error, /Invalid value/)
        end

        describe 'ensure' do
          [ :present, :absent ].each do |value|
            it "should support #{value} as a value to ensure" do
              expect { described_class.new(
                :peer => 'peer.example.com',
                :ensure => value,
              )}.to_not raise_error
            end
          end
        end

        it "should not support other values" do
          expect { described_class.new(
            :peer => 'peer.example.com',
            :ensure => 'unhappy',
          )}.to raise_error(Puppet::Error, /Invalid value/)
        end
      end
    end
  end
end
