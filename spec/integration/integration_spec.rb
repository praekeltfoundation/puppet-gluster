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

      describe 'gluster_peer' do
        it 'should add a single peer' do
          expect(@fake_gluster.peer_hosts).to eq([])
          x = apply_manifest(<<-'END'
            node default {
              gluster_peer { 'gfs1.local': }
            }
            END
          )
          expect(x.any_failed?).to be_nil
          expect(x.changed?.map(&:to_s)).to eq(['Gluster_peer[gfs1.local]'])
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local'])
        end

        it 'should add multiple peers' do
          expect(@fake_gluster.peer_hosts).to eq([])
          x = apply_manifest(<<-'END'
            node default {
              gluster_peer { ['gfs1.local', 'gfs2.local']: }
            }
            END
          )
          expect(x.any_failed?).to be_nil
          expect(x.changed?.map(&:to_s)).to eq(
            ['Gluster_peer[gfs1.local]', 'Gluster_peer[gfs2.local]'])
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local', 'gfs2.local'])
        end

        it 'should only add missing peers' do
          @fake_gluster.add_peer('gfs1.local')
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local'])
          x = apply_manifest(<<-'END'
            node default {
              gluster_peer { ['gfs1.local', 'gfs2.local']: }
            }
            END
          )
          expect(x.any_failed?).to be_nil
          expect(x.changed?.map(&:to_s)).to eq(['Gluster_peer[gfs2.local]'])
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local', 'gfs2.local'])
        end

        it 'should ignore inappropriate peers' do
          expect(@fake_gluster.peer_hosts).to eq([])
          x = apply_manifest(<<-'END'
            node default {
              gluster_peer { ["$ipaddress", 'gfs1.local', 'badpeer.local']:
                ignore_peers => ['badpeer.local'],
              }
            }
            END
          )
          expect(x.any_failed?).to be_nil
          expect(x.changed?.map(&:to_s)).to eq(['Gluster_peer[gfs1.local]'])
          expect(@fake_gluster.peer_hosts).to eq(['gfs1.local'])
        end
      end

    end
  end
end
