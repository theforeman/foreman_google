require 'test_google_helper'

module ForemanGoogle
  module Api
    module V2
      class ComputeResourcesExtensionsTest < GoogleTestCase
        let(:controller_class) do
          Class.new do
            def self.before_action(*)
            end

            include ForemanGoogle::Api::V2::ComputeResourcesExtensions

            attr_accessor :params

            def compute_resource_params
              params[:compute_resource]
            end
          end
        end

        describe '#read_key' do
          it 'reads key file content into password for GCE provider' do
            key_content = '{"type": "service_account", "project_id": "test"}'

            Tempfile.open('gce_key') do |f|
              f.write(key_content)
              f.flush

              ctrl = controller_class.new
              ctrl.params = { 'compute_resource' => { 'provider' => 'GCE', 'key_path' => f.path } }.with_indifferent_access
              ctrl.send(:read_key)

              assert_equal key_content, ctrl.params[:compute_resource][:password]
              assert_not ctrl.params[:compute_resource].key?('key_path')
            end
          end

          it 'skips when provider is not GCE' do
            ctrl = controller_class.new
            ctrl.params = { 'compute_resource' => { 'provider' => 'EC2', 'key_path' => '/nonexistent' } }.with_indifferent_access
            ctrl.send(:read_key)

            assert_nil ctrl.params[:compute_resource][:password]
            assert_equal '/nonexistent', ctrl.params[:compute_resource]['key_path']
          end
        end
      end
    end
  end
end
