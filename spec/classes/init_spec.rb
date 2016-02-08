require 'spec_helper'

describe 'gluster' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts
      end

      describe 'has sensible defaults' do
        # Manage the default repo.
        it { is_expected.to contain_apt__ppa('ppa:gluster/glusterfs-3.7') }
        # Manage the default package.
        it { is_expected.to contain_package('glusterfs-server') }
        # Manage the default service.
        it { is_expected.to contain_service('glusterfs-server') }
      end

      describe 'has sensible ordering' do
        it do
          is_expected.to contain_class(
            'gluster::repo').that_comes_before(
            'Class[gluster::install]').that_comes_before(
            'Class[gluster::service]')
        end
        it do
          is_expected.to contain_package('glusterfs-server').that_notifies(
            'Class[gluster::service]')
        end
      end

      describe 'when the repo is unmanaged' do
        let(:params) { {:repo_manage => false} }
        it { is_expected.not_to contain_apt__ppa('ppa:gluster/glusterfs-3.7') }
        it { is_expected.to contain_package('glusterfs-server') }
        it { is_expected.to contain_package('glusterfs-server') }
      end

      describe 'when the package is unmanaged' do
        let(:params) { {:package_manage => false} }
        it { is_expected.to contain_apt__ppa('ppa:gluster/glusterfs-3.7') }
        it { is_expected.not_to contain_package('glusterfs-server') }
        it { is_expected.to contain_service('glusterfs-server') }
      end

      describe 'when the service is unmanaged' do
        let(:params) { {:service_manage => false} }
        it { is_expected.to contain_apt__ppa('ppa:gluster/glusterfs-3.7') }
        it { is_expected.to contain_package('glusterfs-server') }
        it { is_expected.not_to contain_service('glusterfs-server') }
      end

      describe 'when given an invalid repo source' do
        let(:params) { {:repo_source => 'foo.rb'} }
        it do
          is_expected.to compile.and_raise_error(/'foo.rb' .* not supported/)
        end
      end

      describe 'when given a different package_ensure value' do
        let(:params) { {:package_ensure => 'latest'} }
        it do
          is_expected.to contain_package('glusterfs-server').with(
            'ensure' => 'latest',
          )
        end
      end

      describe 'when given a different package name' do
        let(:params) { {:package_name => 'mygluster'} }
        it { is_expected.not_to contain_package('glusterfs-server') }
        it { is_expected.to contain_package('mygluster') }
      end

      describe 'when given a different service_ensure value' do
        let(:params) { {:service_ensure => 'latest'} }
        it do
          is_expected.to contain_service('glusterfs-server').with(
            'ensure' => 'latest',
          )
        end
      end

      describe 'when given a different service name' do
        let(:params) { {:service_name => 'mygluster'} }
        it { is_expected.not_to contain_service('glusterfs-server') }
        it { is_expected.to contain_service('mygluster') }
      end

    end
  end
end
