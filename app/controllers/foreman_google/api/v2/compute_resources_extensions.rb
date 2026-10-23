module ForemanGoogle
  module Api
    module V2
      module ComputeResourcesExtensions
        extend ActiveSupport::Concern

        # rubocop:disable Rails/LexicallyScopedActionFilter
        included do
          filter_parameters lambda { |key, value|
            value.replace('[FILTERED]') if key == 'key_content'
          }
          before_action :read_key, only: %i[create update]
          before_action :deprecated_params, only: %i[create update]
        end
        # rubocop:enable Rails/LexicallyScopedActionFilter

        private

        def read_key
          return unless gce_provider?

          key_content = extract_key_content
          params[:compute_resource][:password] = key_content if key_content.present?
        end

        def gce_provider?
          provider = action_name == 'create' ? params[:compute_resource][:provider] : @compute_resource&.provider
          provider == 'GCE'
        end

        def extract_key_content
          params[:compute_resource].delete(:key_content) ||
            params[:compute_resource].delete('key_content')
        end

        def deprecated_params
          return unless compute_resource_params['provider'] == 'GCE'

          if compute_resource_params['email']
            msg = _('The email parameter is deprecated, value is automatically loaded from the JSON file')
            Foreman::Deprecation.api_deprecation_warning(msg)
          end

          return unless compute_resource_params['project']
          msg = _('The project parameter is deprecated, value is automatically loaded from the JSON file')
          Foreman::Deprecation.api_deprecation_warning(msg)
        end
      end
    end
  end
end
