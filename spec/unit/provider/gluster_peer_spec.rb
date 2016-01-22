require 'spec_helper'

describe Puppet::Type.type(:gluster_peer).provider(:gluster_peer) do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      before :each do
        Facter.clear
        facts.each do |k, v|
          Facter.stubs(:fact).with(k).returns Facter.add(k) { setcode { v} }
        end
      end

      describe 'class methods' do
        [:instances, :prefetch, :all_peers].each do |method|
          it "should have method named #{method}" do
            expect(described_class).to respond_to method
          end
        end
      end

    end
  end
end
