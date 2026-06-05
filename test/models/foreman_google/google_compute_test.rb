require 'test_google_helper'

module ForemanGoogle
  class GoogleComputeTest < GoogleTestCase
    let(:client) { mock('GoogleAdapter') }
    let(:zone) { 'zone-1' }
    let(:identity) { 'instance-id-or-name' }

    let(:instance) do
      nics = [OpenStruct.new(access_configs: [OpenStruct.new(nat_i_p: '1.2.3.4')], network: 'test/default', network_i_p: '10.10.10.23')]

      OpenStruct.new name: 'instance', network_interfaces: nics,
        creation_timestamp: Time.zone.now, zone: zone,
        machine_type: 'machineTypes/e2-micro'
    end

    subject { ForemanGoogle::GoogleCompute.new(client: client, zone: zone, identity: identity) }

    setup do
      client.stubs(:project_id).returns('project_id')
    end

    describe '#reload' do
      let(:zone) { 'http://test.org/fullurl/zones/zone-1' }
      let(:zone_name) { zone.split('/').last }

      it 'reloads the instance from gce and returns self' do
        client.expects(:instance).with(zone_name, identity).twice
        value(subject.reload).must_equal(subject)
      end
    end

    describe '#persisted?' do
      context 'with identity' do
        it 'is persisted' do
          client.stubs(:instance).with(zone, identity)
          value(subject).must_be(:persisted?)
        end
      end

      context 'without identity' do
        let(:identity) { nil }

        it 'is not persisted' do
          value(subject).wont_be(:persisted?)
        end
      end
    end

    describe '#ready?' do
      it 'is ready with running instance' do
        instance.status = 'RUNNING'
        client.expects(:instance).with(zone, identity).returns(instance)
        value(subject).must_be(:ready?)
      end

      it 'is not ready for not running instance' do
        instance.status = 'PROVISIONING'
        client.expects(:instance).with(zone, identity).returns(instance)
        value(subject).wont_be(:ready?)
      end
    end

    describe '#name & #hostname' do
      it 'default value' do
        args = { network: '' }
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: args)

        assert_includes cr.name, 'foreman-'
        assert_includes cr.hostname, 'foreman-'
      end

      it 'is parameterized' do
        args = { name: 'My new name' }
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: args)
        assert_includes cr.name, 'my-new-name'
        assert_includes cr.hostname, 'my-new-name'
      end
    end

    describe '#network_interfaces' do
      it 'with default value' do
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone)
        assert_includes cr.network_interfaces[0][:network], '/projects/project_id/global/networks/default'
      end

      it 'with custom value' do
        args = { network: 'custom' }
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: args)
        assert_includes cr.network_interfaces[0][:network], '/projects/project_id/global/networks/custom'
      end

      it 'with associated external ip' do
        args = { associate_external_ip: '1' }
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: args)
        expected_nics = [{ network: 'global/networks/default', access_configs: [{ name: 'External NAT', type: 'ONE_TO_ONE_NAT' }] }]

        assert_equal cr.network_interfaces, expected_nics
      end

      it 'with nics' do
        args = { associate_external_ip: '1', network_interfaces: [{ network: 'global/networks/custom' }] }
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: args)
        expected_nics = [{ network: 'global/networks/custom', access_configs: [{ name: 'External NAT', type: 'ONE_TO_ONE_NAT' }] }]

        assert_equal cr.network_interfaces, expected_nics
      end
    end

    describe '#volumes' do
      setup do
        client.stubs(:images).returns([OpenStruct.new(id: 1, name: 'coastal-image', self_link: 'test-self-link')])
        client.stubs(:image).returns(OpenStruct.new(id: 1, name: 'coastal-image', self_link: 'test-self-link'))
      end

      it 'no volumes' do
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone)
        volumes = [Google::Cloud::Compute::V1::AttachedDisk.new(disk_size_gb: 20)]

        assert_equal cr.volumes, volumes
      end

      it 'without image_id' do
        args = { volumes: [{ size_gb: '23' }] }
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: args)
        volume = cr.volumes.first

        assert_equal volume.device_name, "#{cr.name}-disk1"
        assert_empty volume.source
      end

      it 'with source_image' do
        args = { volumes: Array.new(2, { size_gb: '23', source_image: 'centos-stream-8-v20220317' }), image_id: '1' }
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: args)

        assert_equal cr.volumes[0].source, 'test-self-link'
        assert_equal cr.volumes[1].source, ''
      end
    end

    describe '#metadata' do
      let(:ssh_attrs) { { username: 'gce_user', public_key: 'public_key' } }

      it 'with user_data' do
        args = ssh_attrs.merge({ user_data: 'test' })
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: args)

        assert_includes cr.metadata[:items], { key: 'user-data', value: 'test' }
        assert_includes cr.metadata[:items], { key: 'ssh-keys', value: 'gce_user:public_key' }
      end

      it 'no user_data' do
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: ssh_attrs)
        assert_equal cr.metadata, { items: [{ key: 'ssh-keys', value: 'gce_user:public_key' }] }
      end
    end

    it '#pretty_machine_type - with instance' do
      cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, instance: instance)
      assert_equal cr.pretty_machine_type, 'e2-micro'
    end

    it '#pretty_machine_type - without instance' do
      args = { machine_type: 'high-cpu-16' }
      cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: args)
      assert_equal cr.pretty_machine_type, args[:machine_type]
    end

    it '#vm_ip_address' do
      cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, instance: instance)
      assert_equal cr.vm_ip_address, '1.2.3.4'
    end

    it '#private_ip_address' do
      cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, instance: instance)
      assert_equal cr.private_ip_address, '10.10.10.23'
    end

    it '#pretty_image_name' do
      client.stubs(:disk).returns(OpenStruct.new(source_image: '/path/to/centos-source-image'))
      instance.disks = [OpenStruct.new(source: 'path/to/foreman-disk1')]

      cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, instance: instance)
      assert_equal cr.pretty_image_name, 'centos-source-image'
    end

    it '@associate_external_ip' do
      cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone)
      assert_not cr.associate_external_ip

      cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: { associate_external_ip: '1' })
      assert cr.associate_external_ip
    end

    it '@network' do
      cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone)
      assert_equal 'default', cr.network

      cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: { network: 'my-network' })
      assert_equal 'my-network', cr.network
    end

    it '@zone' do
      cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone)
      assert_equal zone, cr.zone
    end

    it '@zone_name' do
      cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, instance: instance)
      assert_equal zone, cr.zone_name
    end

    describe '#status' do
      it 'returns status when persisted' do
        instance.status = 'RUNNING'
        client.expects(:instance).with(zone, identity).returns(instance)
        assert_equal 'RUNNING', subject.status
      end

      it 'returns false when not persisted' do
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone)
        assert_not cr.status
      end
    end

    describe '#state' do
      it 'is an alias for status' do
        instance.status = 'TERMINATED'
        client.expects(:instance).with(zone, identity).returns(instance)
        assert_equal subject.status, subject.state
      end
    end

    describe '#start' do
      it 'delegates to client.start when persisted' do
        client.stubs(:instance).with(zone, identity).returns(instance)
        client.expects(:start).with(zone, identity).returns(true)
        subject.start
      end

      it 'raises when not persisted' do
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone)
        assert_raises(Foreman::Exception) { cr.start }
      end
    end

    describe '#stop' do
      it 'delegates to client.stop when persisted' do
        client.stubs(:instance).with(zone, identity).returns(instance)
        client.expects(:stop).with(zone, identity).returns(true)
        subject.stop
      end

      it 'raises when not persisted' do
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone)
        assert_raises(Foreman::Exception) { cr.stop }
      end
    end

    describe '#to_s' do
      it 'returns the name' do
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: { name: 'my-vm' })
        assert_equal 'my-vm', cr.to_s
      end
    end

    describe '#interfaces' do
      it 'returns network_interfaces' do
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone)
        assert_equal cr.network_interfaces, cr.interfaces
      end
    end

    describe '#vm_description' do
      it 'delegates to pretty_machine_type' do
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, instance: instance)
        assert_equal cr.pretty_machine_type, cr.vm_description
      end
    end

    describe '#vm_ip_address - no network interfaces' do
      it 'returns nil' do
        empty_instance = OpenStruct.new(
          name: 'instance', network_interfaces: [],
          creation_timestamp: Time.zone.now, zone: zone,
          machine_type: 'machineTypes/e2-micro'
        )
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, instance: empty_instance)
        assert_nil cr.vm_ip_address
      end
    end

    describe '#private_ip_address - no network interfaces' do
      it 'returns nil' do
        empty_instance = OpenStruct.new(
          name: 'instance', network_interfaces: [],
          creation_timestamp: Time.zone.now, zone: zone,
          machine_type: 'machineTypes/e2-micro'
        )
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, instance: empty_instance)
        assert_nil cr.private_ip_address
      end
    end

    describe '#pretty_image_name - no disks' do
      it 'returns nil' do
        instance.disks = []
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, instance: instance)
        assert_nil cr.pretty_image_name
      end
    end

    describe '#ip_addresses' do
      it 'returns public and private IP' do
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, instance: instance)
        assert_equal ['1.2.3.4', '10.10.10.23'], cr.ip_addresses
      end
    end

    describe '#serial_port_output' do
      it 'delegates to client' do
        client.stubs(:instance).with(zone, identity).returns(instance)
        client.expects(:serial_port_output).with(zone, identity).returns(OpenStruct.new(contents: 'boot log'))
        assert_equal 'boot log', subject.serial_port_output
      end

      it 'returns nil when client returns nil' do
        client.stubs(:instance).with(zone, identity).returns(instance)
        client.expects(:serial_port_output).with(zone, identity).returns(nil)
        assert_nil subject.serial_port_output
      end
    end

    describe '#volumes_attributes=' do
      it 'is a no-op' do
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone)
        cr.volumes_attributes = { '0' => { size_gb: 10 } }
        assert cr.volumes.any?
      end
    end

    describe '#reload - without identity' do
      it 'returns nil' do
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone)
        assert_nil cr.reload
      end
    end

    describe '#create_volumes' do
      it 'inserts disks and waits for READY' do
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: { volumes: [{ size_gb: '20' }] })

        client.expects(:insert_disk).with(zone, cr.volumes.first.insert_attrs)
        client.expects(:disk).with(zone, cr.volumes.first.device_name).returns(OpenStruct.new(status: 'READY'))
        client.expects(:wait_for).yields.returns({ duration: 1 })

        cr.create_volumes
      end
    end

    describe '#destroy_volumes' do
      it 'deletes each volume disk' do
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: { volumes: [{ size_gb: '20' }] })
        client.expects(:delete_disk).with(zone, cr.volumes.first.device_name)
        cr.destroy_volumes
      end
    end

    describe '#create_instance' do
      it 'calls insert_instance via ComputeAttributes' do
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: { name: 'test-vm', machine_type: 'e2-micro' })
        client.expects(:insert_instance).with(zone, has_key(:name))
        cr.create_instance
      end
    end

    describe '#set_disk_auto_delete' do
      it 'delegates to client' do
        args = { name: 'my-vm' }
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: args)
        client.expects(:set_disk_auto_delete).with(zone, 'my-vm')
        cr.set_disk_auto_delete
      end
    end

    describe '#wait_for' do
      it 'delegates to client.wait_for' do
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone)
        client.expects(:wait_for).yields.returns({ duration: 0 })
        result = cr.wait_for { true }
        assert_equal({ duration: 0 }, result)
      end
    end

    describe '#public_ip_address' do
      it 'is an alias for vm_ip_address' do
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, instance: instance)
        assert_equal cr.vm_ip_address, cr.public_ip_address
      end
    end
  end
end
