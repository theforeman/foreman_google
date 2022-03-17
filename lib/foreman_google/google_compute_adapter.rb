require 'google-cloud-compute'

module ForemanGoogle
  class GoogleComputeAdapter
    def initialize(auth_json_string:)
      @auth_json = JSON.parse(auth_json_string)
    end

    def project_id
      @auth_json['project_id']
    end

    # ------ RESOURCES ------

    def zones
      list('zones')
    end

    def networks
      list('networks')
    end

    def machine_types(zone)
      list('machine_types', zone: zone)
    end

    private

    def list(resource_name, **opts)
      response = resource_client(resource_name).list(project: project_id, **opts).response
      response.items
    rescue ::Google::Cloud::Error => e
      raise Foreman::WrappedException.new(e, 'Cannot list Google resource %s', resource_name)
    end

    def resource_client(resource_name)
      ::Google::Cloud::Compute.public_send(resource_name) do |config|
        config.credentials = @auth_json
      end
    end
  end
end
