require 'spec_helper'

describe 'gluster' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts
      end

      describe 'has sensible defaults' do
        # Add the default repo.
        it { is_expected.to contain_apt__ppa('ppa:gluster/glusterfs-3.7') }
      end

      describe 'when repo unmanaged' do
        let(:params) { {:repo_manage => false} }
        it { should_not contain_apt__ppa('ppa:gluster/glusterfs-3.7') }
      end

      describe 'when given an invalid repo source' do
        let(:params) { {:repo_source => 'foo.rb'} }
        it { should compile.and_raise_error(/'foo.rb' .* not supported/) }
      end
    end
  end
end
