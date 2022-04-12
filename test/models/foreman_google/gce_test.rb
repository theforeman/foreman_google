require 'test_google_helper'

module ForemanGoogle
  class GCETest < GoogleTestCase
    subject { ForemanGoogle::GCE.new(zone: 'zone', password: gauth_json) }
    let(:service) { mock('GoogleAdapter') }

    setup do
      subject.stubs(client: service)
      service.stubs(:project_id).returns('project_id')
    end

    describe '#find_vm_by_uuid' do
      it 'does query gce' do
        instance = stub status: 'RUNNING', name: 'eee',
          zone: '/test/us-east1-b', network_interfaces: [], disks: [],
          metadata: nil, machine_type: 'micro-e2', creation_timestamp: Time.zone.now

        service.expects(:instance).with(subject.zone, 'instance_name').returns(instance)

        compute = subject.find_vm_by_uuid('instance_name')
        value(compute).must_be_kind_of(ForemanGoogle::GoogleCompute)
      end

      it 'throws 404 when instance not found on GCE' do
        service
          .expects(:instance)
          .with(subject.zone, 'non-existing-name-or-id')
          .raises(Foreman::WrappedException.new(Google::Cloud::NotFoundError.new, 'not found'))

        value { subject.find_vm_by_uuid('non-existing-name-or-id') }.must_raise(Foreman::WrappedException)
      end
    end

    describe '#vms' do
      let(:instances) do
        Array.new(2) { |i| OpenStruct.new(name: "instance#{i}", creation_timestamp: Time.zone.now, zone: '/test/us-east1-b') }
      end

      setup do
        service.expects(:instances).returns(instances)
      end

      it 'iteration over the vms array' do
        subject.vms.each_with_index { |instance, i| assert instance.name, instances[i].name }
      end

      it 'all method' do
        subject.vms.all.each_with_index { |instance, i| assert instance.name, instances[i].name }
      end
    end
  end
end
