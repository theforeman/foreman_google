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
        instance = stub(status: 'RUNNING')
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
      let(:instances) { [OpenStruct.new(name: 'instance1'), OpenStruct.new(name: 'instance2')] }

      setup do
        service.expects(:instances).returns(instances)
      end

      it 'iteration over the vms array' do
        subject.vms.each_with_index { |instance, i| assert instance.name, instances[i].name }
      end

      it 'all method' do
        subject.vms.each_with_index { |instance, i| assert instance.name, instances[i].name }
      end
    end
  end
end
