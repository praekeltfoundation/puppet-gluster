require 'spec_helper'

describe 'gluster::service' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts
      end

      describe 'has sensible defaults' do
        it do
          # FIXME: This assumes Debianland.
          is_expected.to contain_service('glusterfs-server').with(
            'ensure' => 'running',
          )
        end
      end

      describe 'when the service is unmanaged' do
        let(:params) { {:manage => false} }
        it { is_expected.not_to contain_service('glusterfs-server') }
      end

      describe 'when given a different ensure value' do
        let(:params) { {:ensure => 'stopped'} }
        it do
          is_expected.to contain_service('glusterfs-server').with(
            'ensure' => 'stopped',
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
