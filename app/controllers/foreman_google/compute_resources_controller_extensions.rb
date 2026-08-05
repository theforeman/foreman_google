module ForemanGoogle
  module ComputeResourcesControllerExtensions
    extend ActiveSupport::Concern

    included do
      before_action :find_resource, only: [:available_subnets]
    end

    def available_subnets
      network = params[:network]
      subnets = @compute_resource.subnets(network).map(&:name)

      respond_to do |format|
        format.json { render json: subnets }
      end
    end

    private

    def action_permission
      case params[:action]
      when 'available_subnets'
        'view'
      else
        super
      end
    end
  end
end
