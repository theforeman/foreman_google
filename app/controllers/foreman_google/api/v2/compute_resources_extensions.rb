module ForemanGoogle
  module Api
    module V2
      module ComputeResourcesExtensions
        extend ActiveSupport::Concern

        # rubocop:disable Rails/LexicallyScopedActionFilter
        included do
          before_action :read_key, only: [:create]
        end
        # rubocop:enable Rails/LexicallyScopedActionFilter

        private

        def read_key
          return unless compute_resource_params['provider'] == 'GCE'
          params[:compute_resource][:password] = File.read(params['compute_resource'].delete('key_path'))
        end
      end
    end
  end
end
