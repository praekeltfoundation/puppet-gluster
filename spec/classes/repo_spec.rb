require 'spec_helper'

describe 'gluster::repo' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts
      end

      describe 'has sensible defaults' do
        it { is_expected.to contain_apt__ppa('ppa:gluster/glusterfs-3.7') }
      end

      describe 'when unmanaged' do
        let(:params) { {:manage => false} }
        it { is_expected.not_to contain_apt__ppa('ppa:gluster/glusterfs-3.7') }
      end

      describe 'when set to an invalid source' do
        let(:params) { {:source => 'foo.rb'} }
        it do
          is_expected.to compile.and_raise_error(/'foo.rb' .* not supported/)
        end
      end

      describe 'when run on an unsupported OS' do
        let(:facts) { facts.merge({:operatingsystem => 'iOS'}) }
        it { is_expected.to compile.and_raise_error(/No repository .* 'iOS'/) }
      end
    end
  end
end
