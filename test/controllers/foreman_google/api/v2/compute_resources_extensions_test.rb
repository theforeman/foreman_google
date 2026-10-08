require 'test_google_helper'

module ForemanGoogle
  module Api
    module V2
      class ComputeResourcesExtensionsTest < GoogleTestCase
        describe 'the real API controller integration' do
          it 'loads the Google parameter extension into the compute resource controller' do
            assert_includes ::Api::V2::ComputeResourcesController.ancestors,
              ::Foreman::Controller::Parameters::ComputeResourceExtension
          end

          it 'permits Google compute resource parameters' do
            context = ::Api::V2::ComputeResourcesController.parameter_filter_context
            params = ActionController::Parameters.new(
              compute_resource: { key_content: '{"type":"service_account"}', zone: 'us-east1-b' }
            )

            filtered = ::Api::V2::ComputeResourcesController
                       .compute_resource_params_filter
                       .filter_params(params, context)

            assert_equal({ 'key_content' => '{"type":"service_account"}', 'zone' => 'us-east1-b' }, filtered.to_h)
          end
        end

        let(:controller_class) do
          Class.new do
            def self.before_action(*)
            end

            def self.filter_parameters(*)
              # Stub for parameter filtering in tests
            end

            include ForemanGoogle::Api::V2::ComputeResourcesExtensions

            attr_accessor :params, :action_name, :compute_resource

            def compute_resource_params
              params[:compute_resource]
            end
          end
        end

        describe '#read_key' do
          it 'copies key_content into password for GCE provider on create' do
            key_content = '{"type": "service_account", "project_id": "test"}'
            ctrl = controller_class.new
            ctrl.action_name = 'create'
            ctrl.params = { 'compute_resource' => { 'provider' => 'GCE', 'key_content' => key_content } }.with_indifferent_access
            ctrl.send(:read_key)

            assert_equal key_content, ctrl.params[:compute_resource][:password]
            assert_not ctrl.params[:compute_resource].key?('key_content')
          end

          it 'copies key_content into password for GCE provider on update' do
            key_content = '{"type": "service_account", "project_id": "test"}'
            ctrl = controller_class.new
            ctrl.action_name = 'update'
            compute_resource = mock('compute_resource')
            compute_resource.stubs(:provider).returns('GCE')
            ctrl.instance_variable_set(:@compute_resource, compute_resource)
            ctrl.params = { 'compute_resource' => { 'key_content' => key_content } }.with_indifferent_access
            ctrl.send(:read_key)

            assert_equal key_content, ctrl.params[:compute_resource][:password]
            assert_not ctrl.params[:compute_resource].key?('key_content')
          end

          it 'skips when provider is not GCE' do
            key_content = '{"type": "service_account", "project_id": "test"}'
            ctrl = controller_class.new
            ctrl.action_name = 'create'
            ctrl.params = { 'compute_resource' => { 'provider' => 'EC2', 'key_content' => key_content } }.with_indifferent_access
            ctrl.send(:read_key)

            assert_nil ctrl.params[:compute_resource][:password]
            assert_equal key_content, ctrl.params[:compute_resource]['key_content']
          end
        end
      end
    end
  end
end
