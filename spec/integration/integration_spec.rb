require 'spec_helper'
require 'integration/helpers'

describe 'integration', :integration => true do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      before :each do
        stub_facts(facts)

        # # Uncomment this to get logging output.
        # Puppet::Util::Log.newdestination(:console)
        # Puppet::Util::Log.level = :info

        @peer_type = Puppet::Type.type(:gluster_peer)
        @peer_provider = @peer_type.provider(:gluster_peer)
        @volume_type = Puppet::Type.type(:gluster_volume)
        @volume_provider = @volume_type.provider(:gluster_volume)

        unconfine(@peer_provider, ['gluster'])
        unconfine(@volume_provider, ['gluster'])
        @fake_gluster = stub_gluster(@peer_provider, @volume_provider)
      end

      describe 'gluster_peer create' do
        it 'should add a single peer (manifest)' do
          expect(@fake_gluster.peer_hosts).to eq([])
          trx = apply_node_manifest(<<-'MANIFEST')
          gluster_peer { 'gfs1.local': }
          MANIFEST
          expect(trx.any_failed?).to be_nil
          expect(trx.changed?.map(&:to_s)).to eq(['Gluster_peer[gfs1.local]'])
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local'])
        end

        it 'should add a single peer (resources)' do
          expect(@fake_gluster.peer_hosts).to eq([])
          trx = apply_catalog_with(@peer_type.new(:peer => 'gfs1.local'))
          expect(trx.any_failed?).to be_nil
          expect(trx.changed?.map(&:to_s)).to eq(['Gluster_peer[gfs1.local]'])
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local'])
        end

        it 'should add multiple peers' do
          expect(@fake_gluster.peer_hosts).to eq([])
          trx = apply_node_manifest(<<-'MANIFEST')
          gluster_peer { ['gfs1.local', 'gfs2.local']: }
          MANIFEST
          expect(trx.any_failed?).to be_nil
          expect(trx.changed?.map(&:to_s)).to eq(
            ['Gluster_peer[gfs1.local]', 'Gluster_peer[gfs2.local]'])
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local', 'gfs2.local'])
        end

        it 'should only add a missing peer' do
          @fake_gluster.add_peer('gfs1.local')
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local'])
          trx = apply_node_manifest(<<-'MANIFEST')
          gluster_peer { ['gfs1.local', 'gfs2.local']: }
          MANIFEST
          expect(trx.any_failed?).to be_nil
          expect(trx.changed?.map(&:to_s)).to eq(['Gluster_peer[gfs2.local]'])
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local', 'gfs2.local'])
        end

        it 'should ignore local peer addresses' do
          expect(@fake_gluster.peer_hosts).to eq([])
          trx = apply_node_manifest(<<-'MANIFEST')
          gluster_peer { ["$ipaddress", 'gfs1.local', 'hostalias.local']:
            local_peer_aliases => ['hostalias.local'],
          }
          MANIFEST
          expect(trx.any_failed?).to be_nil
          expect(trx.changed?.map(&:to_s)).to eq(['Gluster_peer[gfs1.local]'])
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local'])
        end

        it 'should not explode if a peer is unreachable (old msg)' do
          @fake_gluster.peer_unreachable(
            'gfs1.local', 'Probe returned with unknown errno 107')
          expect(@fake_gluster.peer_hosts).to eq([])
          trx = apply_node_manifest(<<-'MANIFEST')
          gluster_peer { 'gfs1.local': }
          MANIFEST
          expect(trx.any_failed?).to be_nil
          # Event though the status didn't actually change, there's no easy way
          # to prevent the change event from being fired.
          expect(trx.changed?.map(&:to_s)).to eq(['Gluster_peer[gfs1.local]'])
          expect(@fake_gluster.peer_hosts).to eq([])
        end

        it 'should not explode if a peer is unreachable (new msg)' do
          @fake_gluster.peer_unreachable(
            'gfs1.local',
            'Probe returned with Transport endpoint is not connected')
          expect(@fake_gluster.peer_hosts).to eq([])
          trx = apply_node_manifest(<<-'MANIFEST')
          gluster_peer { 'gfs1.local': }
          MANIFEST
          expect(trx.any_failed?).to be_nil
          # Event though the status didn't actually change, there's no easy way
          # to prevent the change event from being fired.
          expect(trx.changed?.map(&:to_s)).to eq(['Gluster_peer[gfs1.local]'])
          expect(@fake_gluster.peer_hosts).to eq([])
        end

        it 'should add a peer when it becomes reachable' do
          manifest = <<-'MANIFEST'
          gluster_peer { 'gfs1.local': }
          MANIFEST

          @fake_gluster.peer_unreachable('gfs1.local')
          expect(@fake_gluster.peer_hosts).to eq([])
          trx = apply_node_manifest(manifest)
          expect(trx.any_failed?).to be_nil
          # Event though the status didn't actually change, there's no easy way
          # to prevent the change event from being fired.
          expect(trx.changed?.map(&:to_s)).to eq(['Gluster_peer[gfs1.local]'])
          expect(@fake_gluster.peer_hosts).to eq([])

          @fake_gluster.peer_reachable('gfs1.local')
          trx = apply_node_manifest(manifest)
          expect(trx.any_failed?).to be_nil
          expect(trx.changed?.map(&:to_s)).to eq(['Gluster_peer[gfs1.local]'])
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local'])
        end

        it 'should fail on an unexpected error' do
          @fake_gluster.set_error(-1, 2, 'A bad thing happened.')
          trx = apply_node_manifest(<<-'MANIFEST')
          gluster_peer { 'gfs1.local': }
          MANIFEST
          expect(trx.any_failed?.resource.to_s).to eq(
            'Gluster_peer[gfs1.local]')
          expect(trx.changed?.map(&:to_s)).to eq([])
          expect(@fake_gluster.peer_hosts).to eq([])
        end
      end


      describe 'gluster_peer destroy' do
        it 'should remove a single peer' do
          @fake_gluster.add_peer('gfs1.local')
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local'])
          trx = apply_node_manifest(<<-'MANIFEST')
          gluster_peer { 'gfs1.local':
            ensure => 'absent',
          }
          MANIFEST
          expect(trx.any_failed?).to be_nil
          expect(trx.changed?.map(&:to_s)).to eq(['Gluster_peer[gfs1.local]'])
          expect(@fake_gluster.peer_hosts).to eq([])
        end

        it 'should not remove a missing peer' do
          @fake_gluster.add_peer('gfs1.local')
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local'])
          trx = apply_node_manifest(<<-'MANIFEST')
          gluster_peer { 'missing.local':
            ensure => 'absent',
          }
          MANIFEST
          expect(trx.any_failed?).to be_nil
          expect(trx.changed?.map(&:to_s)).to eq([])
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local'])
        end

        it 'should remove multiple peers' do
          @fake_gluster.add_peers('gfs1.local', 'gfs2.local')
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local', 'gfs2.local'])
          trx = apply_node_manifest(<<-'MANIFEST')
          gluster_peer { ['gfs1.local', 'gfs2.local']:
            ensure => 'absent',
          }
          MANIFEST
          expect(trx.any_failed?).to be_nil
          expect(trx.changed?.map(&:to_s)).to eq(
            ['Gluster_peer[gfs1.local]', 'Gluster_peer[gfs2.local]'])
          expect(@fake_gluster.peer_hosts).to eq([])
        end
      end


      describe 'gluster_volume create' do
        it 'should add a volume with a single local brick' do
          expect(@fake_gluster.volume_names).to eq([])
          trx = apply_node_manifest(<<-'MANIFEST')
          gluster_volume { 'vol1':
            bricks => ["${fqdn}:/b1/v1"],
          }
          MANIFEST
          expect(trx.any_failed?).to be_nil
          expect(trx.changed?.map(&:to_s)).to eq(['Gluster_volume[vol1]'])
          expect(@fake_gluster.volume_names).to eq(['vol1'])
          expect(@fake_gluster.get_volume('vol1').started?).to eq(true)
        end

        it 'should add a volume with force' do
          expect(@fake_gluster.volume_names).to eq([])
          trx = apply_node_manifest(<<-'MANIFEST')
          gluster_volume { 'vol1':
            bricks => ["${fqdn}:/b1/v1"],
            force => true,
          }
          MANIFEST
          expect(trx.any_failed?).to be_nil
          expect(trx.changed?.map(&:to_s)).to eq(['Gluster_volume[vol1]'])
          expect(@fake_gluster.volume_names).to eq(['vol1'])
          expect(@fake_gluster.get_volume('vol1').started?).to eq(true)
          # TODO: Check that force was actually used.
        end

        it 'should add a volume with a single remote brick' do
          expect(@fake_gluster.volume_names).to eq([])
          trx = apply_node_manifest(<<-'MANIFEST')
          gluster_peer { 'gfs1.local': }
          gluster_volume { 'vol1':
            bricks => ['gfs1.local:/b1/v1'],
          }
          MANIFEST
          expect(trx.any_failed?).to be_nil
          expect(trx.changed?.map(&:to_s)).to contain_exactly(
            'Gluster_peer[gfs1.local]', 'Gluster_volume[vol1]')
          expect(@fake_gluster.volume_names).to eq(['vol1'])
          expect(@fake_gluster.get_volume('vol1').started?).to eq(true)
        end

        it 'should add a volume with two bricks' do
          expect(@fake_gluster.volume_names).to eq([])
          trx = apply_node_manifest(<<-'MANIFEST')
          gluster_peer { 'gfs1.local': }
          gluster_volume { 'vol1':
            bricks => ["${fqdn}:/b1/v1", 'gfs1.local:/b1/v1'],
          }
          MANIFEST
          expect(trx.any_failed?).to be_nil
          expect(trx.changed?.map(&:to_s)).to contain_exactly(
            'Gluster_peer[gfs1.local]', 'Gluster_volume[vol1]')
          expect(@fake_gluster.volume_names).to eq(['vol1'])
          vol = @fake_gluster.get_volume('vol1')
          expect(vol.started?).to eq(true)
          expect(vol.bricks.map { |b| b[:name] }).to contain_exactly(
            "#{Facter.value(:fqdn)}:/b1/v1", 'gfs1.local:/b1/v1')
          expect(vol[:replica]).to eq(1)
        end

        it 'should add a replicated volume with two bricks' do
          expect(@fake_gluster.volume_names).to eq([])
          trx = apply_node_manifest(<<-'MANIFEST')
          gluster_peer { 'gfs1.local': }
          gluster_volume { 'vol1':
            replica => 2,
            bricks => ["${fqdn}:/b1/v1", 'gfs1.local:/b1/v1'],
          }
          MANIFEST
          expect(trx.any_failed?).to be_nil
          expect(trx.changed?.map(&:to_s)).to contain_exactly(
            'Gluster_peer[gfs1.local]', 'Gluster_volume[vol1]')
          expect(@fake_gluster.volume_names).to eq(['vol1'])
          vol = @fake_gluster.get_volume('vol1')
          expect(vol.started?).to eq(true)
          expect(vol.bricks.map { |b| b[:name] }).to contain_exactly(
            "#{Facter.value(:fqdn)}:/b1/v1", 'gfs1.local:/b1/v1')
          expect(vol[:replica]).to eq('2')
        end

        it 'should reject an invalid replica value' do
          expect {
            apply_node_manifest(<<-'MANIFEST')
            gluster_volume { 'vol1':
              replica => 'twelve',
              bricks => ["${fqdn}:/b1/v1"],
            }
            MANIFEST
          }.to raise_error(Puppet::ResourceError)
        end

        it 'should only add a missing volume' do
          @fake_gluster.add_volume('vol1', ["#{Facter.value(:fqdn)}:/b1/v1"])
          expect(@fake_gluster.volume_names).to eq(['vol1'])
          trx = apply_node_manifest(<<-'MANIFEST')
          gluster_volume { 'vol1':
            bricks => ["${fqdn}:/b1/v1"],
          }
          MANIFEST
          expect(trx.any_failed?).to be_nil
          expect(trx.changed?.map(&:to_s)).to eq([])
          expect(@fake_gluster.volume_names).to eq(['vol1'])
          expect(@fake_gluster.get_volume('vol1').started?).to eq(true)
        end

        it 'should start a stopped volume' do
          @fake_gluster.add_volume(
            'vol1', ["#{Facter.value(:fqdn)}:/b1/v1"],
            :status => 2, :statusStr => 'Stopped')
          expect(@fake_gluster.volume_names).to eq(['vol1'])
          expect(@fake_gluster.get_volume('vol1').started?).to eq(false)
          trx = apply_node_manifest(<<-'MANIFEST')
          gluster_volume { 'vol1':
            bricks => ["${fqdn}:/b1/v1"],
          }
          MANIFEST
          expect(trx.any_failed?).to be_nil
          expect(trx.changed?.map(&:to_s)).to eq(['Gluster_volume[vol1]'])
          expect(@fake_gluster.volume_names).to eq(['vol1'])
          expect(@fake_gluster.get_volume('vol1').started?).to eq(true)
        end

        # TODO: More edge case tests.

      end


      describe 'gluster_volume ensure_stopped' do
        it 'should add a volume without starting it' do
          expect(@fake_gluster.volume_names).to eq([])
          trx = apply_node_manifest(<<-'MANIFEST')
          gluster_volume { 'vol1':
            ensure => 'stopped',
            bricks => ["${fqdn}:/b1/v1"],
          }
          MANIFEST
          expect(trx.any_failed?).to be_nil
          expect(trx.changed?.map(&:to_s)).to eq(['Gluster_volume[vol1]'])
          expect(@fake_gluster.volume_names).to eq(['vol1'])
          expect(@fake_gluster.get_volume('vol1').started?).to eq(false)
        end

        it 'should only add a missing volume' do
          @fake_gluster.add_volume(
            'vol1', ["#{Facter.value(:fqdn)}:/b1/v1"],
            :status => 2, :statusStr => 'Stopped')
          expect(@fake_gluster.volume_names).to eq(['vol1'])
          expect(@fake_gluster.get_volume('vol1').started?).to eq(false)
          trx = apply_node_manifest(<<-'MANIFEST')
          gluster_volume { 'vol1':
            ensure => 'stopped',
            bricks => ["${fqdn}:/b1/v1"],
          }
          MANIFEST
          expect(trx.any_failed?).to be_nil
          expect(trx.changed?.map(&:to_s)).to eq([])
          expect(@fake_gluster.volume_names).to eq(['vol1'])
          expect(@fake_gluster.get_volume('vol1').started?).to eq(false)
        end

        it 'should stop a started volume' do
          @fake_gluster.add_volume('vol1', ["#{Facter.value(:fqdn)}:/b1/v1"])
          expect(@fake_gluster.volume_names).to eq(['vol1'])
          expect(@fake_gluster.get_volume('vol1').started?).to eq(true)
          trx = apply_node_manifest(<<-'MANIFEST')
          gluster_volume { 'vol1':
            ensure => 'stopped',
            bricks => ["${fqdn}:/b1/v1"],
          }
          MANIFEST
          expect(trx.any_failed?).to be_nil
          expect(trx.changed?.map(&:to_s)).to eq(['Gluster_volume[vol1]'])
          expect(@fake_gluster.volume_names).to eq(['vol1'])
          expect(@fake_gluster.get_volume('vol1').started?).to eq(false)
        end

        # TODO: More edge case tests.

      end


      describe 'gluster_volume destroy' do
        it 'should remove a started volume' do
          @fake_gluster.add_volume('vol1', ["#{Facter.value(:fqdn)}:/b1/v1"])
          expect(@fake_gluster.volume_names).to eq(['vol1'])
          expect(@fake_gluster.get_volume('vol1').started?).to eq(true)
          trx = apply_node_manifest(<<-'MANIFEST')
          gluster_volume { 'vol1': ensure => 'absent' }
          MANIFEST
          expect(trx.any_failed?).to be_nil
          expect(trx.changed?.map(&:to_s)).to eq(['Gluster_volume[vol1]'])
          expect(@fake_gluster.volume_names).to eq([])
        end

        it 'should remove a stopped volume' do
          @fake_gluster.add_volume(
            'vol1', ["#{Facter.value(:fqdn)}:/b1/v1"],
            :status => 2, :statusStr => 'Stopped')
          expect(@fake_gluster.volume_names).to eq(['vol1'])
          expect(@fake_gluster.get_volume('vol1').started?).to eq(false)
          trx = apply_node_manifest(<<-'MANIFEST')
          gluster_volume { 'vol1': ensure => 'absent' }
          MANIFEST
          expect(trx.any_failed?).to be_nil
          expect(trx.changed?.map(&:to_s)).to eq(['Gluster_volume[vol1]'])
          expect(@fake_gluster.volume_names).to eq([])
        end

        it 'should only remove an existing volume' do
          expect(@fake_gluster.volume_names).to eq([])
          trx = apply_node_manifest(<<-'MANIFEST')
          gluster_volume { 'vol1': ensure => 'absent' }
          MANIFEST
          expect(trx.any_failed?).to be_nil
          expect(trx.changed?.map(&:to_s)).to eq([])
          expect(@fake_gluster.volume_names).to eq([])
        end

        # TODO: More edge case tests.

      end

    end
  end
end
