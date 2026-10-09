module ForemanGoogle
  module Api
    module V2
      module ComputeResourcesExtensions
        extend ActiveSupport::Concern

        # rubocop:disable Rails/LexicallyScopedActionFilter
        included do
          before_action :read_key, only: %i[create update]
          before_action :deprecated_params, only: %i[create update]
        end
        # rubocop:enable Rails/LexicallyScopedActionFilter

        private

        def read_key # rubocop:disable Metrics/AbcSize
          return unless compute_resource_params['provider'] == 'GCE'

          key_path = params['compute_resource'].delete('key_path')
          key_content = params['compute_resource'].delete('key_content')

          if key_content.present?
            params[:compute_resource][:password] = key_content
          elsif key_path.present?
            params[:compute_resource][:password] = File.read(key_path)
          end
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
