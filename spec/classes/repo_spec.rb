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
        it { should_not contain_apt__ppa('ppa:gluster/glusterfs-3.7') }
      end

      describe 'when set to an invalid source' do
        let(:params) { {:source => 'foo.rb'} }
        it { should compile.and_raise_error(/'foo.rb' .* not supported/) }
      end

      describe 'when run on an unsupported OS' do
        let(:facts) { {:osfamily => 'iOS'} }
        it { should compile.and_raise_error(/No repository .* 'iOS'/) }
      end
    end
  end
end
