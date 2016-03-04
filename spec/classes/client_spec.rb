require 'spec_helper'

describe 'gluster::client' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts
      end

      describe 'has sensible defaults' do
        it { is_expected.to contain_apt__ppa('ppa:gluster/glusterfs-3.7') }
        it do
          is_expected.to contain_package('glusterfs-client')
            .with('ensure' => 'installed')
            .that_requires('Class[gluster::repo]')
        end
      end

      describe 'when the repo is unmanaged' do
        let(:params) { {:repo_manage => false} }
        it { is_expected.not_to contain_apt__ppa('ppa:gluster/glusterfs-3.7') }
        it do
          is_expected.to contain_package('glusterfs-client')
            .with('ensure' => 'installed')
        end
      end

      describe 'when given a different ensure value' do
        let(:params) { {:ensure => 'latest'} }
        it do
          is_expected.to contain_package('glusterfs-client').with(
            'ensure' => 'latest',
          )
        end
      end

      describe 'when given a different package name' do
        let(:params) { {:package_name => 'mygluster'} }
        it { is_expected.not_to contain_package('glusterfs-client') }
        it { is_expected.to contain_package('mygluster') }
      end
    end
  end
end
