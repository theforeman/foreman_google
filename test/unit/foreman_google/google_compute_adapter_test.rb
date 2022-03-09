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

    describe '#machine_types' do
      setup do
        stub_request(:get, 'https://compute.googleapis.com/compute/v1/projects/coastal-haven-123456/zones/us-east1-b/machineTypes')
          .to_return(body: File.read(File.join(__dir__, '..', '..', 'fixtures', 'machine_types.json')))
      end

      it 'list machine_types' do
        assert_equal ['machine_type_001'], subject.machine_types('us-east1-b').map(&:name)
      end
    end

    describe '#images' do
      setup do
        stub_request(:get, 'https://compute.googleapis.com/compute/v1/projects/coastal-haven-123456/global/images')
          .to_return(body: File.read(File.join(__dir__, '..', '..', 'fixtures', 'images_coastal.json')))
      end

      it 'list images' do
        stub_request(:get, 'https://compute.googleapis.com/compute/v1/projects/centos-cloud/global/images')
          .to_return(body: File.read(File.join(__dir__, '..', '..', 'fixtures', 'images_centos_cloud.json')))

        subject.stub(:all_projects, %w[centos-cloud]) do
          assert_equal %w[coastal-image centos-6], subject.images.map(&:name)
        end
      end

      it 'list images with filter' do
        not_found_body = File.read(File.join(__dir__, '..', '..', 'fixtures', 'images_nothing_found.json'))
        %w[coastal-haven-123456 centos-cloud].each do |project|
          url = "https://compute.googleapis.com/compute/v1/projects/#{project}/global/images?filter=name%20=%20%22NOTHING_FOUND%22"
          stub_request(:get, url).to_return(body: not_found_body)
        end

        subject.stub(:all_projects, %w[centos-cloud]) do
          assert_empty subject.images(filter: 'name = "NOTHING_FOUND"')
        end
      end

      it 'ignore deprecated images' do
        stub_request(:get, 'https://compute.googleapis.com/compute/v1/projects/deprecated/global/images')
          .to_return(body: File.read(File.join(__dir__, '..', '..', 'fixtures', 'images_deprecated.json')))

        subject.stub(:all_projects, %w[deprecated]) do
          assert_equal ['coastal-image'], subject.images.map(&:name)
        end
      end
    end
  end
end
