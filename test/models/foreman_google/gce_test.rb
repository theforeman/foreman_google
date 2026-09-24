require 'test_google_helper'

module ForemanGoogle
  class GCETest < GoogleTestCase
    subject { ForemanGoogle::GCE.new(zone: 'us-east1-b', password: gauth_json) }
    let(:service) { mock('GoogleAdapter') }

    let(:instance_args) do
      nics = [OpenStruct.new(access_configs: [OpenStruct.new(nat_i_p: '1.2.3.4')], network: 'test/default', network_i_p: '10.10.10.23')]

      { name: "instance-#{Time.now.to_i}", network_interfaces: nics,
        creation_timestamp: Time.zone.now, zone: '/test/us-east1-b',
        machine_type: 'machineTypes/e2-micro' }
    end

    setup do
      subject.stubs(client: service)
      service.stubs(:project_id).returns('project_id')
    end

    describe '#to_label' do
      it 'includes name, zone, and provider' do
        subject.name = 'my-gce'
        expected = 'my-gce (us-east1-b-Google)'
        assert_equal expected, subject.to_label
      end
    end

    describe '#capabilities' do
      it 'returns image and new_volume' do
        assert_equal %i[image new_volume], subject.capabilities
      end
    end

    describe '#provided_attributes' do
      it 'includes ip mapped to vm_ip_address' do
        attrs = subject.provided_attributes
        assert_equal :vm_ip_address, attrs[:ip]
      end
    end

    describe '#user_data_supported?' do
      it 'returns true' do
        assert subject.user_data_supported?
      end
    end

    describe '#zone' do
      it 'reads from url attribute' do
        subject.url = 'us-central1-a'
        assert_equal 'us-central1-a', subject.zone
      end
    end

    describe '#zone=' do
      it 'writes to url attribute' do
        subject.zone = 'europe-west1-b'
        assert_equal 'europe-west1-b', subject.url
      end
    end

    describe 'validations' do
      it 'is valid with name, zone, and password' do
        subject.name = 'test-gce'
        assert subject.valid?, "Expected subject to be valid, got errors: #{subject.errors.full_messages}"
      end

      it 'requires password' do
        cr = ForemanGoogle::GCE.new(zone: 'us-east1-b', password: nil)
        assert_not cr.valid?
        assert_includes cr.errors.attribute_names, :password
      end

      it 'requires zone' do
        cr = ForemanGoogle::GCE.new(zone: nil, password: gauth_json)
        assert_not cr.valid?
        assert_includes cr.errors.attribute_names, :zone
      end

      it 'requires name' do
        cr = ForemanGoogle::GCE.new(name: nil, zone: 'us-east1-b', password: gauth_json)
        assert_not cr.valid?
        assert_includes cr.errors.attribute_names, :name
      end
    end

    describe '#zones' do
      it 'returns zone names from client' do
        zones = [OpenStruct.new(name: 'us-east1-b'), OpenStruct.new(name: 'us-west1-a')]
        service.expects(:zones).returns(zones)
        assert_equal %w[us-east1-b us-west1-a], subject.zones
      end

      it 'is aliased as available_zones' do
        zones = [OpenStruct.new(name: 'us-east1-b')]
        service.expects(:zones).returns(zones)
        assert_equal %w[us-east1-b], subject.available_zones
      end
    end

    describe '#networks' do
      it 'returns network names from client' do
        networks = [OpenStruct.new(name: 'default'), OpenStruct.new(name: 'custom')]
        service.expects(:networks).returns(networks)
        assert_equal %w[default custom], subject.networks
      end
    end

    describe '#available_networks' do
      it 'returns full network objects from client' do
        network_objects = [OpenStruct.new(name: 'default')]
        service.expects(:networks).returns(network_objects)
        assert_equal network_objects, subject.available_networks
      end
    end

    describe '#region' do
      it 'derives region from zone by stripping the last segment' do
        subject.zone = 'europe-west1-b'
        assert_equal 'europe-west1', subject.region
      end

      it 'handles multi-segment zone names' do
        subject.zone = 'us-central1-a'
        assert_equal 'us-central1', subject.region
      end

      it 'handles asia zones' do
        subject.zone = 'asia-east1-c'
        assert_equal 'asia-east1', subject.region
      end
    end

    describe '#subnets' do
      let(:subnets) do
        [
          OpenStruct.new(name: 'subnet-a', network: 'projects/project_id/global/networks/vpc-one'),
          OpenStruct.new(name: 'subnet-b', network: 'projects/project_id/global/networks/vpc-two'),
          OpenStruct.new(name: 'subnet-c', network: 'projects/project_id/global/networks/vpc-one'),
        ]
      end

      setup do
        service.stubs(:subnetworks).with('us-east1').returns(subnets)
      end

      it 'returns all subnets when no network filter' do
        result = subject.subnets
        assert_equal 3, result.length
        assert_equal %w[subnet-a subnet-b subnet-c], result.map(&:name)
      end

      it 'filters subnets by network name' do
        result = subject.subnets('vpc-one')
        assert_equal 2, result.length
        assert_equal %w[subnet-a subnet-c], result.map(&:name)
      end

      it 'returns empty when no subnets match network' do
        result = subject.subnets('non-existent')
        assert_empty result
      end

      it 'delegates to client.subnetworks with derived region' do
        service.expects(:subnetworks).with('us-east1').returns([])
        subject.subnets
      end
    end

    describe '#machine_types' do
      it 'returns machine types for the zone from client' do
        types = [OpenStruct.new(name: 'e2-micro')]
        service.expects(:machine_types).with('us-east1-b').returns(types)
        assert_equal types, subject.machine_types
      end

      it 'is aliased as available_flavors' do
        types = [OpenStruct.new(name: 'n1-standard-1')]
        service.expects(:machine_types).with('us-east1-b').returns(types)
        assert_equal types, subject.available_flavors
      end
    end

    describe '#available_images' do
      it 'delegates to client.images with filter' do
        images = [OpenStruct.new(name: 'centos-7')]
        service.expects(:images).with(filter: nil).returns(images)
        assert_equal images, subject.available_images
      end

      it 'passes custom filter to client' do
        images = [OpenStruct.new(name: 'centos-7')]
        service.expects(:images).with(filter: 'name = "centos"').returns(images)
        assert_equal images, subject.available_images(filter: 'name = "centos"')
      end
    end

    describe '#filter_for_images' do
      it 'defaults to nil' do
        assert_nil subject.filter_for_images
      end
    end

    describe '#google_project_id' do
      it 'delegates to client' do
        assert_equal 'project_id', subject.google_project_id
      end
    end

    describe '#find_vm_by_uuid' do
      it 'does query gce' do
        instance = OpenStruct.new(**instance_args)

        service.expects(:instance).with(subject.zone, instance.name).returns(instance)

        compute = subject.find_vm_by_uuid(instance.name)
        value(compute).must_be_kind_of(ForemanGoogle::GoogleCompute)
      end

      it 'throws 404 when instance not found on GCE' do
        service
          .expects(:instance)
          .with(subject.zone, 'non-existing-name-or-id')
          .raises(ActiveRecord::RecordNotFound)

        value { subject.find_vm_by_uuid('non-existing-name-or-id') }.must_raise(ActiveRecord::RecordNotFound)
      end
    end

    describe '#vms' do
      let(:instances) do
        Array.new(2) { |_i| OpenStruct.new(**instance_args) }
      end

      setup do
        service.expects(:instances).returns(instances)
      end

      it 'iteration over the vms array' do
        subject.vms.each_with_index { |instance, i| assert_equal instances[i].name, instance.name }
      end

      it 'all method' do
        subject.vms.all.each_with_index { |instance, i| assert_equal instances[i].name, instance.name }
      end
    end

    describe '#new_vm' do
      it 'assigns provided attributes' do
        vm = subject.new_vm(name: 'test-vm', machine_type: 'e2-micro')
        assert_equal 'test-vm', vm.name
        assert_equal 'e2-micro', vm.machine_type
      end

      it 'converts volumes_attributes nested hash' do
        attrs = {
          'name' => 'test-vm',
          'volumes_attributes' => { '0' => { 'size_gb' => '20' } },
        }
        vm = subject.new_vm(attrs)
        assert_equal 1, vm.volumes.size
        assert_equal 20, vm.volumes.first.size_gb
      end
    end

    describe '#create_vm' do
      setup do
        service.expects(:image).returns(nil)
      end

      it 'without OS image' do
        value { subject.create_vm({ image_id: 0 }) }.must_raise(::Foreman::Exception)
      end
    end

    describe '#create_vm success path' do
      let(:os_image) { OpenStruct.new(username: 'gce_user', name: 'centos-7') }
      let(:gce_image) { OpenStruct.new(id: 42, self_link: 'image-link') }
      let(:key_pair_obj) { OpenStruct.new(public: 'ssh-rsa AAAA') }
      let(:vm) { mock('GoogleCompute') }

      setup do
        service.stubs(:image).returns(gce_image)
        service.stubs(:instance)
        subject.stubs(:images).returns(stub(find_by: os_image))
        subject.stubs(:key_pair).returns(key_pair_obj)
        subject.stubs(:new_vm).returns(vm)
        vm.stubs(:hostname).returns('test-vm')

        vm.expects(:create_volumes)
        vm.expects(:create_instance)
        vm.expects(:set_disk_auto_delete)
      end

      it 'creates volumes, instance, and sets auto-delete' do
        result = subject.create_vm({ image_id: 42 })
        assert_kind_of ForemanGoogle::GoogleCompute, result
      end
    end

    describe '#create_vm rollback on error' do
      let(:os_image) { OpenStruct.new(username: 'gce_user', name: 'centos-7') }
      let(:gce_image) { OpenStruct.new(id: 42, self_link: 'image-link') }
      let(:key_pair_obj) { OpenStruct.new(public: 'ssh-rsa AAAA') }
      let(:vm) { mock('GoogleCompute') }

      setup do
        subject.stubs(:images).returns(stub(find_by: os_image))
        service.stubs(:image).returns(gce_image)
        subject.stubs(:key_pair).returns(key_pair_obj)
        subject.stubs(:new_vm).returns(vm)
        vm.stubs(:create_volumes).raises(::Google::Cloud::Error.new('quota exceeded'))

        vm.expects(:destroy_volumes)
      end

      it 'destroys volumes and raises WrappedException' do
        assert_raises(Foreman::WrappedException) { subject.create_vm({ image_id: 42 }) }
      end
    end

    describe '#destroy_vm' do
      it 'calls set_disk_auto_delete and delete_instance' do
        service.expects(:set_disk_auto_delete).with('us-east1-b', 'vm-uuid')
        service.expects(:delete_instance).with('us-east1-b', 'vm-uuid')
        subject.destroy_vm('vm-uuid')
      end

      it 'returns true when VM not found' do
        service.expects(:set_disk_auto_delete).raises(ActiveRecord::RecordNotFound)
        assert subject.destroy_vm('missing-vm')
      end
    end

    describe '#new_volume' do
      it 'returns an AttachedDisk with 20 GB default' do
        vol = subject.new_volume
        assert_kind_of Google::Cloud::Compute::V1::AttachedDisk, vol
        assert_equal 20, vol.disk_size_gb
      end

      it 'merges provided attributes' do
        vol = subject.new_volume(device_name: 'boot-disk')
        assert_equal 'boot-disk', vol.device_name
        assert_equal 20, vol.disk_size_gb
      end
    end

    describe '#console' do
      let(:vm) { mock('GoogleCompute') }

      setup do
        subject.stubs(:find_vm_by_uuid).returns(vm)
      end

      it 'returns serial output when VM is ready' do
        vm.stubs(:ready?).returns(true)
        vm.stubs(:serial_port_output).returns('boot log...')
        vm.stubs(:name).returns('test-vm')

        result = subject.console('test-vm')
        assert_equal 'boot log...', result['output']
        assert_equal 'log', result[:type]
        assert_equal 'test-vm', result[:name]
        assert result['timestamp'].is_a?(Time)
      end

      it 'raises when VM is not ready' do
        vm.stubs(:ready?).returns(false)
        assert_raises(::Foreman::Exception) { subject.console('test-vm') }
      end
    end

    describe '#associated_host' do
      it 'calls associate_by with ip addresses' do
        vm = OpenStruct.new(public_ip_address: '1.2.3.4', private_ip_address: '10.0.0.1')
        subject.expects(:associate_by).with('ip', ['1.2.3.4', '10.0.0.1'])
        subject.associated_host(vm)
      end
    end

    describe '#vm_ready' do
      it 'polls until vm is ready' do
        vm = mock('GoogleCompute')
        vm.stubs(:reload).returns(vm)
        vm.stubs(:ready?).returns(false, true)
        vm.stubs(:wait_for).yields.returns({ duration: 2 })

        result = subject.vm_ready(vm)
        assert_equal({ duration: 2 }, result)
      end
    end
  end
end
