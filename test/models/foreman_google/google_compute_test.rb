require 'test_google_helper'

module ForemanGoogle
  class GoogleComputeTest < GoogleTestCase
    let(:client) { mock('GoogleAdapter') }
    let(:zone) { 'zone-1' }
    let(:identity) { 'instance-id-or-name' }

    subject { ForemanGoogle::GoogleCompute.new(client: client, zone: zone, identity: identity) }

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
  end
end
