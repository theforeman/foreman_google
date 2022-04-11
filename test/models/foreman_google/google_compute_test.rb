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

    it '#pretty_machine_type' do
      instance = OpenStruct.new(machine_type: 'https://www.googleapis.com/compute/v1/projects/coastal-haven-123456/zones/us-east1-b/machineTypes/e2-micro')
      cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, instance: instance)

      assert_equal cr.pretty_machine_type, 'e2-micro'
    end

    describe 'instance_variables' do
      let(:new_args) { { name: 'new-name' } }
      let(:instance) { OpenStruct.new(name: 'instance-name') }

      it 'with args for new' do
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: new_args)
        assert_equal cr.name, new_args[:name]
      end

      it 'with set instance' do
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, instance: instance)
        assert_equal cr.name, instance.name
      end

      it 'with args for new and with instance' do
        cr = ForemanGoogle::GoogleCompute.new(client: client, zone: zone, args: new_args, instance: instance)
        assert_equal cr.name, instance.name
      end
    end
  end
end
