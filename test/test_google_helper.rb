# This calls the main test_helper in Foreman-core
require 'test_helper'

# Add plugin to FactoryBot's paths
FactoryBot.definition_file_paths << File.join(File.dirname(__FILE__), 'factories')
FactoryBot.reload

class GoogleTestCase < ActiveSupport::TestCase
  let(:google_access_token) { 'ya29.c.stubbed_token' }
  let(:gce_cr) { FactoryBot.create(:compute_resource, :google_gce) }
  let(:google_project_id) { gce_cr.google_project_id }
  let(:gauth_json) { gce_cr.password }

  setup do
    ::Signet::OAuth2::Client.any_instance.stubs(fetch_access_token!: google_access_token)
  end
end
