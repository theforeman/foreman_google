require 'test_google_helper'

module GoogleCloudCompute
  class ComputeAttributesTest < GoogleTestCase
    let(:client) { mock('GoogleAdapter') }
    let(:zone) { 'zone-1' }

    setup do
      client.stubs(:project_id).returns('project_id')
    end

    describe 'new instance' do
      describe '#name & #hostname' do
        it 'default value' do
          subject = GoogleCloudCompute::ComputeAttributes.new(client, zone)

          assert_includes subject.name, 'foreman-'
          assert_includes subject.hostname, 'foreman-'
        end

        it 'is parameterized' do
          subject = GoogleCloudCompute::ComputeAttributes.new(client, zone, { name: 'My new name' })

          assert_includes subject.name, 'my-new-name'
          assert_includes subject.hostname, 'my-new-name'
        end
      end
    end

    describe '#network_interfaces' do
      it 'with default value' do
        subject = GoogleCloudCompute::ComputeAttributes.new(client, zone)

        assert_includes subject.network, 'default'
        assert_includes subject.network_interfaces[0][:network], '/projects/project_id/global/networks/default'
      end

      it 'with custom value' do
        subject = GoogleCloudCompute::ComputeAttributes.new(client, zone, { network: 'custom' })

        assert_includes subject.network, 'custom'
        assert_includes subject.network_interfaces[0][:network], '/projects/project_id/global/networks/custom'
      end

      it 'with associated external ip' do
        subject = GoogleCloudCompute::ComputeAttributes.new(client, zone, { associate_external_ip: '1' })
        expected_nics = [{ network: 'global/networks/default', access_configs: [{ name: 'External NAT', type: 'ONE_TO_ONE_NAT' }] }]

        assert_equal subject.network_interfaces, expected_nics
      end

      it 'with nics' do
        nics = [{ network: 'global/networks/custom' }]
        args = { associate_external_ip: '1', network_interfaces: nics }
        subject = GoogleCloudCompute::ComputeAttributes.new(client, zone, args)
        expected_nics = [{ network: 'global/networks/custom', access_configs: [{ name: 'External NAT', type: 'ONE_TO_ONE_NAT' }] }]

        assert_equal subject.network_interfaces, expected_nics
      end
    end

    describe '#volumes' do
      setup do
        client.stubs(:images).returns([OpenStruct.new(id: 1, name: 'coastal-image', self_link: 'test-self-link')])
      end

      it 'no volumes' do
        subject = GoogleCloudCompute::ComputeAttributes.new(client, zone, { volumes: [] })

        assert_equal subject.volumes, []
      end

      it 'without image_id' do
        subject = GoogleCloudCompute::ComputeAttributes.new(client, zone, { volumes: [{ size_gb: '23' }] })
        volume = subject.volumes.first

        assert_equal volume[:name], "#{subject.name}-disk1"
        assert_nil volume[:source_image]
      end

      it 'image not found' do
        args = { volumes: [{ size_gb: '23' }], image_id: '0' }
        value { GoogleCloudCompute::ComputeAttributes.new(client, zone, args) }.must_raise(::Foreman::Exception)
      end

      it 'with source_image' do
        args = { volumes: [{ size_gb: '23', source_image: 'centos-stream-8-v20220317' }], image_id: '1' }
        subject = GoogleCloudCompute::ComputeAttributes.new(client, zone, args)

        assert_equal subject.volumes.first[:source_image], 'test-self-link'
      end
    end

    describe '#metadata' do
      it 'with user_data' do
        subject = GoogleCloudCompute::ComputeAttributes.new(client, zone, { user_data: 'test' })
        assert_equal subject.metadata, { items: [{ key: 'user-data', value: 'test' }] }
      end

      it 'no user_data' do
        subject = GoogleCloudCompute::ComputeAttributes.new(client, zone)
        assert_nil subject.metadata
      end
    end
  end
end
