module ForemanGoogle
  module ComputeResourcesControllerExtensions
    extend ActiveSupport::Concern

    def available_subnets
      find_resource
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
