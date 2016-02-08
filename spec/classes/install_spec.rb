require 'spec_helper'

describe 'gluster::install' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts
      end

      describe 'has sensible defaults' do
        it do
          is_expected.to contain_package('glusterfs-server').with(
            'ensure' => 'installed',
          )
        end
      end

      describe 'when the package is unmanaged' do
        let(:params) { {:manage => false} }
        it { is_expected.not_to contain_package('glusterfs-server') }
      end

      describe 'when given a different ensure value' do
        let(:params) { {:ensure => 'latest'} }
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
    end
  end
end
