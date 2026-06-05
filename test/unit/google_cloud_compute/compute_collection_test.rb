require 'test_google_helper'

module GoogleCloudCompute
  class ComputeCollectionTest < GoogleTestCase
    let(:client) { mock('GoogleAdapter') }
    let(:zone) { 'us-east1-b' }

    setup do
      client.stubs(:project_id).returns('project_id')
    end

    describe 'with instances' do
      let(:instances) do
        nics = [OpenStruct.new(access_configs: [OpenStruct.new(nat_i_p: '1.2.3.4')],
          network: 'projects/project_id/global/networks/default', network_i_p: '10.0.0.1')]
        [
          OpenStruct.new(id: 1, name: 'vm-1', network_interfaces: nics,
            creation_timestamp: Time.zone.now, zone: zone, machine_type: 'machineTypes/e2-micro'),
          OpenStruct.new(id: 2, name: 'vm-2', network_interfaces: nics,
            creation_timestamp: Time.zone.now, zone: zone, machine_type: 'machineTypes/e2-small'),
        ]
      end

      setup do
        client.stubs(:instances).with(zone).returns(instances)
      end

      it 'wraps instances as GoogleCompute objects' do
        collection = GoogleCloudCompute::ComputeCollection.new(client, zone)
        collection.each do |vm|
          assert_kind_of ForemanGoogle::GoogleCompute, vm
        end
      end

      it 'iterates via each' do
        collection = GoogleCloudCompute::ComputeCollection.new(client, zone)
        names = collection.map(&:name)
        assert_equal %w[vm-1 vm-2], names
      end

      it 'returns all VMs via all' do
        collection = GoogleCloudCompute::ComputeCollection.new(client, zone)
        assert_equal 2, collection.all.length
      end

      it 'is Enumerable' do
        collection = GoogleCloudCompute::ComputeCollection.new(client, zone)
        assert_kind_of Enumerable, collection
        assert_equal 2, collection.count
      end
    end

    describe 'with empty instance list' do
      setup do
        client.stubs(:instances).with(zone).returns([])
      end

      it 'returns empty collection' do
        collection = GoogleCloudCompute::ComputeCollection.new(client, zone)
        assert_empty collection.all
      end

      it 'iterates zero times' do
        collection = GoogleCloudCompute::ComputeCollection.new(client, zone)
        count = 0
        collection.each { count += 1 }
        assert_equal 0, count
      end
    end

    describe 'with attrs' do
      it 'passes attrs to client.instances' do
        client.expects(:instances).with(zone, filter: 'name = "test"').returns([])
        GoogleCloudCompute::ComputeCollection.new(client, zone, filter: 'name = "test"')
      end
    end
  end
end
