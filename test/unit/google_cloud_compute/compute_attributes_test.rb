require 'test_google_helper'

module GoogleCloudCompute
  class ComputeAttributesTest < GoogleTestCase
    let(:client) { mock('GoogleAdapter') }
    subject { GoogleCloudCompute::ComputeAttributes.new(client) }

    setup do
      client.stubs(:project_id).returns('my-project')
    end

    describe '#for_new' do
      describe 'name handling' do
        it 'generates a default name with foreman- prefix when name is nil' do
          result = subject.for_new({})
          assert_match(/\Aforeman-\d+\z/, result[:name])
          assert_equal result[:name], result[:hostname]
        end

        it 'parameterizes the provided name' do
          result = subject.for_new(name: 'My VM Name')
          assert_equal 'my-vm-name', result[:name]
          assert_equal 'my-vm-name', result[:hostname]
        end
      end

      describe 'network handling' do
        it 'defaults to default network' do
          result = subject.for_new({})
          assert_equal 'default', result[:network]
        end

        it 'uses custom network name' do
          result = subject.for_new(network: 'custom-net')
          assert_equal 'custom-net', result[:network]
        end

        it 'builds full URL without external IP' do
          result = subject.for_new(network: 'default')
          expected_url = 'https://compute.googleapis.com/compute/v1/projects/my-project/global/networks/default'
          assert_equal expected_url, result[:network_interfaces][0][:network]
        end

        it 'adds NAT access config with external IP' do
          result = subject.for_new(associate_external_ip: '1')
          nic = result[:network_interfaces][0]
          assert_equal 'global/networks/default', nic[:network]
          assert_equal [{ name: 'External NAT', type: 'ONE_TO_ONE_NAT' }], nic[:access_configs]
        end

        it 'uses selected network with external IP instead of hardcoded default' do
          result = subject.for_new(network: 'my-custom-vpc', associate_external_ip: '1')
          nic = result[:network_interfaces][0]
          assert_equal 'global/networks/my-custom-vpc', nic[:network]
          assert_equal [{ name: 'External NAT', type: 'ONE_TO_ONE_NAT' }], nic[:access_configs]
        end

        it 'uses custom network interfaces with external IP' do
          result = subject.for_new(
            associate_external_ip: '1',
            network_interfaces: [{ network: 'global/networks/my-net' }]
          )
          nic = result[:network_interfaces][0]
          assert_equal 'global/networks/my-net', nic[:network]
          assert_equal [{ name: 'External NAT', type: 'ONE_TO_ONE_NAT' }], nic[:access_configs]
        end
      end

      describe 'subnetwork handling' do
        it 'omits subnetwork from network_interfaces when not provided' do
          result = subject.for_new(network: 'default')
          assert_nil result[:network_interfaces][0][:subnetwork]
          assert_nil result[:subnetwork]
        end

        it 'includes subnetwork in network_interfaces without external IP' do
          result = subject.for_new(network: 'my-vpc', subnetwork: 'my-subnet', zone: 'europe-west1-b')
          expected = 'projects/my-project/regions/europe-west1/subnetworks/my-subnet'
          assert_equal expected, result[:network_interfaces][0][:subnetwork]
          assert_equal 'my-subnet', result[:subnetwork]
        end

        it 'includes subnetwork in network_interfaces with external IP' do
          result = subject.for_new(network: 'my-vpc', subnetwork: 'my-subnet', zone: 'us-central1-a', associate_external_ip: '1')
          expected = 'projects/my-project/regions/us-central1/subnetworks/my-subnet'
          assert_equal expected, result[:network_interfaces][0][:subnetwork]
          assert_equal [{ name: 'External NAT', type: 'ONE_TO_ONE_NAT' }], result[:network_interfaces][0][:access_configs]
        end

        it 'builds correct subnetwork URL with project and region derived from zone' do
          result = subject.for_new(network: 'corp-vpc', subnetwork: 'corp-subnet', zone: 'asia-east1-c')
          expected = 'projects/my-project/regions/asia-east1/subnetworks/corp-subnet'
          assert_equal expected, result[:network_interfaces][0][:subnetwork]
        end

        it 'omits subnetwork when blank string' do
          result = subject.for_new(network: 'default', subnetwork: '', zone: 'us-east1-b')
          assert_nil result[:network_interfaces][0][:subnetwork]
        end
      end

      describe 'associate_external_ip boolean casting' do
        it 'casts string 1 to true' do
          result = subject.for_new(associate_external_ip: '1')
          assert result[:associate_external_ip]
        end

        it 'casts string 0 to false' do
          result = subject.for_new(associate_external_ip: '0')
          assert_not result[:associate_external_ip]
        end

        it 'defaults to false when absent' do
          result = subject.for_new({})
          assert_not result[:associate_external_ip]
        end
      end

      describe 'volume construction' do
        it 'creates a default 20 GB disk when no volumes' do
          result = subject.for_new({})
          assert_equal 1, result[:volumes].length
          assert_equal 20, result[:volumes].first.disk_size_gb
        end

        it 'creates volumes with custom size' do
          result = subject.for_new(volumes: [{ size_gb: '50' }])
          assert_equal 50, result[:volumes].first.disk_size_gb
        end

        it 'sets source image on first volume when image_id is provided' do
          image = OpenStruct.new(id: 1, self_link: 'projects/my-project/global/images/centos-7')
          client.stubs(:image).with(1).returns(image)

          result = subject.for_new(
            volumes: [{ size_gb: '20' }, { size_gb: '30' }],
            image_id: '1'
          )

          assert_equal 'projects/my-project/global/images/centos-7', result[:volumes][0].source
          assert_empty result[:volumes][1].source
        end

        it 'names disks sequentially' do
          result = subject.for_new(name: 'test-vm', volumes: [{ size_gb: '20' }, { size_gb: '30' }])
          assert_equal 'test-vm-disk1', result[:volumes][0].device_name
          assert_equal 'test-vm-disk2', result[:volumes][1].device_name
        end

        it 'accepts disk_size_gb as an alternative key' do
          result = subject.for_new(volumes: [{ disk_size_gb: '40' }])
          assert_equal 40, result[:volumes].first.disk_size_gb
        end
      end

      describe 'metadata construction' do
        it 'includes ssh-keys' do
          result = subject.for_new(username: 'gce_user', public_key: 'ssh-rsa AAAA')
          ssh_item = result[:metadata][:items].find { |i| i[:key] == 'ssh-keys' }
          assert_equal 'gce_user:ssh-rsa AAAA', ssh_item[:value]
        end

        it 'includes user-data when present' do
          result = subject.for_new(username: 'user', public_key: 'key', user_data: '#cloud-config')
          ud_item = result[:metadata][:items].find { |i| i[:key] == 'user-data' }
          assert_equal '#cloud-config', ud_item[:value]
        end

        it 'omits user-data when blank' do
          result = subject.for_new(username: 'user', public_key: 'key')
          keys = result[:metadata][:items].map { |i| i[:key] }
          assert_not_includes keys, 'user-data'
        end
      end

      it 'passes through machine_type and image_id' do
        result = subject.for_new(machine_type: 'e2-micro', image_id: '42')
        assert_equal 'e2-micro', result[:machine_type]
        assert_equal '42', result[:image_id]
      end
    end

    describe '#for_create' do
      let(:instance) do
        vol1 = Google::Cloud::Compute::V1::AttachedDisk.new(device_name: 'vm-disk1')
        vol2 = Google::Cloud::Compute::V1::AttachedDisk.new(device_name: 'vm-disk2')
        OpenStruct.new(
          name: 'test-vm',
          zone: 'us-east1-b',
          machine_type: 'e2-micro',
          volumes: [vol1, vol2],
          network_interfaces: [{ network: 'global/networks/default' }],
          metadata: { items: [{ key: 'ssh-keys', value: 'user:key' }] }
        )
      end

      it 'builds machine_type URL from zone' do
        result = subject.for_create(instance)
        assert_equal 'zones/us-east1-b/machineTypes/e2-micro', result[:machine_type]
      end

      it 'builds disk source paths' do
        result = subject.for_create(instance)
        assert_equal 'zones/us-east1-b/disks/vm-disk1', result[:disks][0][:source]
        assert_equal 'zones/us-east1-b/disks/vm-disk2', result[:disks][1][:source]
      end

      it 'marks first disk as boot' do
        result = subject.for_create(instance)
        assert result[:disks][0][:boot]
        assert_not result[:disks][1][:boot]
      end

      it 'includes network_interfaces and metadata' do
        result = subject.for_create(instance)
        assert_equal instance.network_interfaces, result[:network_interfaces]
        assert_equal instance.metadata, result[:metadata]
      end

      it 'includes name' do
        result = subject.for_create(instance)
        assert_equal 'test-vm', result[:name]
      end
    end

    describe '#for_instance' do
      let(:nics) do
        [OpenStruct.new(network: 'projects/my-project/global/networks/custom', subnetwork: 'projects/my-project/regions/us-west1/subnetworks/my-subnet', network_i_p: '10.0.0.1')]
      end
      let(:instance) do
        OpenStruct.new(
          name: 'existing-vm',
          creation_timestamp: Time.zone.parse('2024-01-15 10:00:00'),
          zone: 'projects/my-project/zones/us-west1-a',
          machine_type: 'zones/us-west1-a/machineTypes/n1-standard-1',
          network_interfaces: nics,
          disks: [OpenStruct.new(device_name: 'disk1')],
          metadata: { items: [] }
        )
      end

      it 'extracts zone_name from full zone URL' do
        result = subject.for_instance(instance)
        assert_equal 'us-west1-a', result[:zone_name]
      end

      it 'extracts network name from full URL' do
        result = subject.for_instance(instance)
        assert_equal 'custom', result[:network]
      end

      it 'extracts subnetwork name from full URL' do
        result = subject.for_instance(instance)
        assert_equal 'my-subnet', result[:subnetwork]
      end

      it 'converts creation_timestamp to DateTime' do
        result = subject.for_instance(instance)
        assert_kind_of DateTime, result[:creation_timestamp]
      end

      it 'passes through name and hostname' do
        result = subject.for_instance(instance)
        assert_equal 'existing-vm', result[:name]
        assert_equal 'existing-vm', result[:hostname]
      end

      it 'passes through disks as volumes and metadata' do
        result = subject.for_instance(instance)
        assert_equal instance.disks, result[:volumes]
        assert_equal instance.metadata, result[:metadata]
      end

      it 'passes through machine_type' do
        result = subject.for_instance(instance)
        assert_equal instance.machine_type, result[:machine_type]
      end
    end
  end
end
