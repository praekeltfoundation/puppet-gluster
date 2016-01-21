require 'spec_helper'

describe Puppet::Type.type(:gluster_volume) do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      before :each do
        Facter.clear
        facts.each do |k, v|
          Facter.stubs(:fact).with(k).returns Facter.add(k) { setcode { v} }
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

        # :name

        # :force

        # :replica

        # :bricks

        describe 'ensure' do
          [ :present, :absent, :stopped ].each do |value|
            it "should support #{value} as a value to ensure" do
              expect {described_class.new(
                :name => 'foo',
                :ensure => value,
              )}.to_not raise_error
            end
          end

          it "should not support other values" do
            expect { described_class.new(
              :name => 'foo',
              :ensure => 'unhappy',
            )}.to raise_error(Puppet::Error, /Invalid value/)
          end
        end
      end
    end
  end
end
