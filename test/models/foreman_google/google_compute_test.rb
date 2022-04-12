require 'test_google_helper'

module ForemanGoogle
  class GoogleComputeTest < GoogleTestCase
    let(:client) { mock('GoogleAdapter') }
    let(:zone) { 'zone-1' }
    let(:identity) { 'instance-id-or-name' }

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
        instance = stub status: 'RUNNING', name: 'eee',
          zone: '/test/us-east1-b', network_interfaces: [], disks: [],
          metadata: nil, machine_type: 'micro-e2', creation_timestamp: Time.zone.now
        client.expects(:instance).with(zone, identity).returns(instance)
        value(subject).must_be(:ready?)
      end

      it 'is not ready for not running instance' do
        instance = stub status: 'PROVISIONING', name: 'eee',
          zone: '/test/us-east1-b', network_interfaces: [], disks: [],
          metadata: nil, machine_type: 'micro-e2', creation_timestamp: Time.zone.now

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
        nics = [{ network: 'global/networks/custom' }]
        args = { associate_external_ip: '1', network_interfaces: nics }
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: args)
        expected_nics = [{ network: 'global/networks/custom', access_configs: [{ name: 'External NAT', type: 'ONE_TO_ONE_NAT' }] }]

        assert_equal cr.network_interfaces, expected_nics
      end
    end

    describe '#volumes' do
      setup do
        client.stubs(:images).returns([OpenStruct.new(id: 1, name: 'coastal-image', self_link: 'test-self-link')])
      end

      it 'no volumes' do
        args = { volumes: [] }
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: args)

        assert_equal cr.volumes, []
      end

      it 'without image_id' do
        args = { volumes: [{ size_gb: '23' }] }
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: args)
        volume = cr.volumes.first

        assert_equal volume[:name], "#{cr.name}-disk1"
        assert_nil volume[:source_image]
      end

      it 'image not found' do
        args = { volumes: [{ size_gb: '23' }], image_id: '0' }
        value { ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: args) }.must_raise(::Foreman::Exception)
      end

      it 'with source_image' do
        args = { volumes: [{ size_gb: '23', source_image: 'centos-stream-8-v20220317' }], image_id: '1' }
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: args)

        volume = cr.volumes.first
        assert_equal volume[:source_image], 'test-self-link'
      end
    end

    describe '#metadata' do
      it 'with user_data' do
        args = { user_data: 'test' }
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: args)
        assert_equal cr.metadata, { items: [{ key: 'user-data', value: 'test' }] }
      end

      it 'no user_data' do
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone)
        assert_nil cr.metadata
      end
    end

    it '#pretty_machine_type' do
      machine_type = 'https://www.googleapis.com/compute/v1/projects/coastal-haven-123456/zones/us-east1-b/machineTypes/e2-micro'
      instance = OpenStruct.new(name: 'instance', machine_type: machine_type, creation_timestamp: Time.zone.now, zone: '/test/us-east1-b')

      cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, instance: instance)
      assert_equal cr.pretty_machine_type, 'e2-micro'
    end

    it '#public_ip_address' do
      nics = [OpenStruct.new(access_configs: [OpenStruct.new(nat_i_p: '1.2.3.4')])]
      instance = OpenStruct.new(name: 'instance', network_interfaces: nics, creation_timestamp: Time.zone.now, zone: '/test/us-east1-b')

      cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, instance: instance)
      assert_equal cr.public_ip_address, '1.2.3.4'
    end

    it '#private_ip_address' do
      nics = [OpenStruct.new(network_i_p: '10.10.10.23')]
      instance = OpenStruct.new(name: 'instance', network_interfaces: nics, creation_timestamp: Time.zone.now, zone: '/test/us-east1-b')

      cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, instance: instance)
      assert_equal cr.private_ip_address, '10.10.10.23'
    end

    it '#pretty_image_name' do
      client.stubs(:disk).returns(OpenStruct.new(source_image: '/path/to/centos-source-image'))

      disks = [OpenStruct.new(device_name: 'foreman-disk1')]
      instance = OpenStruct.new(name: 'instance', disks: disks, creation_timestamp: Time.zone.now, zone: '/test/us-east1-b')

      cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, instance: instance)
      assert_equal cr.pretty_image_name, 'centos-source-image'
    end
  end
end
