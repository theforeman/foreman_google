require 'test_google_helper'
require 'foreman_google/google_compute_adapter'

require 'google/cloud/compute/v1/zones/credentials'
module ForemanGoogle
  class GoogleComputeAdapterTest < GoogleTestCase
    subject { ForemanGoogle::GoogleComputeAdapter.new(auth_json_string: gauth_json) }

    describe 'authentication' do
      it 'passes the auth json to the service client' do
        credentials = stub(client: stub(apply: { authorization: "Bearer #{google_access_token}" }))
        ::Google::Cloud::Compute::V1::Zones::Credentials.expects(:new).with(JSON.parse(gauth_json), has_key(:scope)).returns(credentials)
        stub_request(:get, 'https://compute.googleapis.com/compute/v1/projects/coastal-haven-123456/zones')
          .to_return(body: '{
            "id": "projects/coastal-haven-123456/zones",
            "items": [],
            "selfLink": "https://www.googleapis.com/compute/v1/projects/coastal-haven-123456/zones",
            "kind": "compute#zoneList"
          }')
        subject.zones
      end
    end

    describe '#zones' do
      setup do
        stub_request(:get, 'https://compute.googleapis.com/compute/v1/projects/coastal-haven-123456/zones')
          .to_return(body: File.read(File.join(__dir__, '..', '..', 'fixtures', 'zones.json')))
      end

      it 'show zones' do
        zones = subject.zones
        value(zones.first.name).must_be_kind_of(String)
        value(zones.first.description).must_be_kind_of(String)
      end
    end

    describe '#networks' do
      setup do
        stub_request(:get, 'https://compute.googleapis.com/compute/v1/projects/coastal-haven-123456/global/networks')
          .to_return(body: File.read(File.join(__dir__, '..', '..', 'fixtures', 'networks.json')))
      end

      it 'show networks' do
        assert_equal ['default'], subject.networks.map(&:name)
      end
    end
  end
end
