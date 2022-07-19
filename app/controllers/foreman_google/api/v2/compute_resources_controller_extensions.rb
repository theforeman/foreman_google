module ForemanGoogle
  module Api
    module V2
      module ComputeResourcesControllerExtensions
        module ApipieExtensions
          extend Apipie::DSL::Concern

          update_api(:create, :update) do
            param :compute_resource, Hash do
              param :key_path, String, desc: N_('Certificate path, for GCE only')
              param :zone, String, desc: N_('Zone, for GCE only')
            end
          end
        end
      end
    end
  end
end
