require 'spec_helper'
require 'integration/helpers'

describe 'integration', :integration => true do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      before :each do
        stub_facts(facts)

        @peer_type = Puppet::Type.type(:gluster_peer)
        @peer_provider = @peer_type.provider(:gluster_peer)
        @volume_type = Puppet::Type.type(:gluster_volume)
        @volume_provider = @volume_type.provider(:gluster_volume)

        unconfine(@peer_provider, ['gluster'])
        @fake_gluster = stub_gluster(@peer_provider)
      end

      describe 'gluster_peer create' do
        it 'should add a single peer (manifest)' do
          expect(@fake_gluster.peer_hosts).to eq([])
          x = apply_node_manifest(<<-'MANIFEST')
          gluster_peer { 'gfs1.local': }
          MANIFEST
          expect(x.any_failed?).to be_nil
          expect(x.changed?.map(&:to_s)).to eq(['Gluster_peer[gfs1.local]'])
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local'])
        end

        it 'should add a single peer (resources)' do
          expect(@fake_gluster.peer_hosts).to eq([])
          x = apply_catalog_with(@peer_type.new(:peer => 'gfs1.local'))
          expect(x.any_failed?).to be_nil
          expect(x.changed?.map(&:to_s)).to eq(['Gluster_peer[gfs1.local]'])
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local'])
        end

        it 'should add multiple peers' do
          expect(@fake_gluster.peer_hosts).to eq([])
          x = apply_node_manifest(<<-'MANIFEST')
          gluster_peer { ['gfs1.local', 'gfs2.local']: }
          MANIFEST
          expect(x.any_failed?).to be_nil
          expect(x.changed?.map(&:to_s)).to eq(
            ['Gluster_peer[gfs1.local]', 'Gluster_peer[gfs2.local]'])
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local', 'gfs2.local'])
        end

        it 'should only add missing peers' do
          @fake_gluster.add_peer('gfs1.local')
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local'])
          x = apply_node_manifest(<<-'MANIFEST')
          gluster_peer { ['gfs1.local', 'gfs2.local']: }
          MANIFEST
          expect(x.any_failed?).to be_nil
          expect(x.changed?.map(&:to_s)).to eq(['Gluster_peer[gfs2.local]'])
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local', 'gfs2.local'])
        end

        it 'should ignore inappropriate peers' do
          expect(@fake_gluster.peer_hosts).to eq([])
          x = apply_node_manifest(<<-'MANIFEST')
          gluster_peer { ["$ipaddress", 'gfs1.local', 'badpeer.local']:
            ignore_peers => ['badpeer.local'],
          }
          MANIFEST
          expect(x.any_failed?).to be_nil
          expect(x.changed?.map(&:to_s)).to eq(['Gluster_peer[gfs1.local]'])
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local'])
        end

        it 'should not explode if a peer is unreachable (old msg)' do
          @fake_gluster.peer_unreachable(
            'gfs1.local', 'Probe returned with unknown errno 107')
          expect(@fake_gluster.peer_hosts).to eq([])
          x = apply_node_manifest(<<-'MANIFEST')
          gluster_peer { 'gfs1.local': }
          MANIFEST
          expect(x.any_failed?).to be_nil
          # Event though the status didn't actually change, there's no easy way
          # to prevent the change event from being fired.
          expect(x.changed?.map(&:to_s)).to eq(['Gluster_peer[gfs1.local]'])
          expect(@fake_gluster.peer_hosts).to eq([])
        end

        it 'should not explode if a peer is unreachable (new msg)' do
          @fake_gluster.peer_unreachable(
            'gfs1.local',
            'Probe returned with Transport endpoint is not connected')
          expect(@fake_gluster.peer_hosts).to eq([])
          x = apply_node_manifest(<<-'MANIFEST')
          gluster_peer { 'gfs1.local': }
          MANIFEST
          expect(x.any_failed?).to be_nil
          # Event though the status didn't actually change, there's no easy way
          # to prevent the change event from being fired.
          expect(x.changed?.map(&:to_s)).to eq(['Gluster_peer[gfs1.local]'])
          expect(@fake_gluster.peer_hosts).to eq([])
        end

        it 'should add a peer when it becomes reachable' do
          manifest = <<-'MANIFEST'
          gluster_peer { 'gfs1.local': }
          MANIFEST

          @fake_gluster.peer_unreachable('gfs1.local')
          expect(@fake_gluster.peer_hosts).to eq([])
          x = apply_node_manifest(manifest)
          expect(x.any_failed?).to be_nil
          # Event though the status didn't actually change, there's no easy way
          # to prevent the change event from being fired.
          expect(x.changed?.map(&:to_s)).to eq(['Gluster_peer[gfs1.local]'])
          expect(@fake_gluster.peer_hosts).to eq([])

          @fake_gluster.peer_reachable('gfs1.local')
          x = apply_node_manifest(manifest)
          expect(x.any_failed?).to be_nil
          expect(x.changed?.map(&:to_s)).to eq(['Gluster_peer[gfs1.local]'])
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local'])
        end

        it 'should fail on an unexpected error' do
          @fake_gluster.set_error(-1, 2, 'A bad thing happened.')
          x = apply_node_manifest(<<-'MANIFEST')
          gluster_peer { 'gfs1.local': }
          MANIFEST
          expect(x.any_failed?.resource.to_s).to eq('Gluster_peer[gfs1.local]')
          expect(x.changed?.map(&:to_s)).to eq([])
          expect(@fake_gluster.peer_hosts).to eq([])
        end
      end

      describe 'gluster_peer destroy' do
        it 'should remove a single peer' do
          @fake_gluster.add_peer('gfs1.local')
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local'])
          x = apply_node_manifest(<<-'MANIFEST')
          gluster_peer { 'gfs1.local':
            ensure => 'absent',
          }
          MANIFEST
          expect(x.any_failed?).to be_nil
          expect(x.changed?.map(&:to_s)).to eq(['Gluster_peer[gfs1.local]'])
          expect(@fake_gluster.peer_hosts).to eq([])
        end

        it 'should not remove a missing peer' do
          @fake_gluster.add_peer('gfs1.local')
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local'])
          x = apply_node_manifest(<<-'MANIFEST')
          gluster_peer { 'missing.local':
            ensure => 'absent',
          }
          MANIFEST
          expect(x.any_failed?).to be_nil
          expect(x.changed?.map(&:to_s)).to eq([])
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local'])
        end

        it 'should remove multiple peers' do
          @fake_gluster.add_peers('gfs1.local', 'gfs2.local')
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local', 'gfs2.local'])
          x = apply_node_manifest(<<-'MANIFEST')
          gluster_peer { ['gfs1.local', 'gfs2.local']:
            ensure => 'absent',
          }
          MANIFEST
          expect(x.any_failed?).to be_nil
          expect(x.changed?.map(&:to_s)).to eq(
            ['Gluster_peer[gfs1.local]', 'Gluster_peer[gfs2.local]'])
          expect(@fake_gluster.peer_hosts).to eq([])
        end
      end

    end
  end
end
