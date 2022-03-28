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
      let(:instance) { mock('Google::Compute::Instance') }

      setup do
        client.expects(:instance).with(zone, identity).returns(instance)
      end

      it 'is ready with running instance' do
        instance.expects(:status).returns('RUNNING')
        value(subject).must_be(:ready?)
      end

      it 'is not ready for not running instance' do
        instance.expects(:status).returns('PROVISIONING')
        value(subject).wont_be(:ready?)
      end
    end

    describe '#name & #hostname' do
      it 'default value' do
        args = { network: '' }
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: args)

        assert_includes cr.name, 'foreman_'
        assert_includes cr.hostname, 'foreman_'
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

    describe '#disks' do
      setup do
        client.stubs(:images).returns([OpenStruct.new(id: 1, name: 'coastal-image')])
      end

      it 'no volumes' do
        args = { volumes: [] }
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: args)

        assert_equal cr.disks, []
      end

      it 'without image_id' do
        args = { volumes: [{ size_gb: '23' }] }
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: args)
        disk = cr.disks.first

        assert_equal disk.name, "#{cr.name}-disk1"
        assert_nil disk.source_image
      end

      it 'image not found' do
        args = { volumes: [{ size_gb: '23' }], image_id: '0' }
        value { ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: args) }.must_raise(::Foreman::Exception)
      end

      it 'with source_image' do
        args = { volumes: [{ size_gb: '23', source_image: 'centos-stream-8-v20220317' }], image_id: '1' }
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: args)

        disk = cr.disks.first
        assert_equal disk.source_image, 'coastal-image'
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
  end
end
