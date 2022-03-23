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

    # Returns an Google::Instance identified by instance_identity within given zone.
    # @param zone [String] eighter full url or just zone name
    # @param instance_identity [String] eighter an instance name or its id
    def instance(zone, instance_identity)
      get('instances', instance: instance_identity, zone: zone)
    end

    def zones
      list('zones')
    end

    def networks
      list('networks')
    end

    def machine_types(zone)
      list('machine_types', zone: zone)
    end

    def start(zone, instance_identity)
      manage_instance(:start, zone, instance_identity)
    end

    def stop(zone, instance_identity)
      manage_instance(:stop, zone, instance_identity)
    end

    # Setting filter to '(deprecated.state != "DEPRECATED") AND (deprecated.state != "OBSOLETE")'
    # doesn't work and returns empty array, no idea what is happening there
    def images(filter: nil)
      projects = [project_id] + all_projects
      all_images = projects.map { |project| list_images(project, filter: filter) }
      all_images.flatten.reject(&:deprecated)
    end

    private

    def list(resource_name, **opts)
      response = resource_client(resource_name).list(project: project_id, **opts).response
      response.items
    rescue ::Google::Cloud::Error => e
      raise Foreman::WrappedException.new(e, 'Cannot list Google resource %s', resource_name)
    end

    def list_images(project, **opts)
      resource_name = 'images'
      response = resource_client(resource_name).list(project: project, **opts).response
      response.items
    rescue ::Google::Cloud::Error => e
      raise Foreman::WrappedException.new(e, 'Cannot list Google resource %s', resource_name)
    end

    def get(resource_name, **opts)
      resource_client(resource_name).get(project: project_id, **opts)
    rescue ::Google::Cloud::Error => e
      raise Foreman::WrappedException.new(e, 'Could not fetch Google resource %s', resource_name)
    end

    def manage_instance(action, zone, instance_identity)
      resource_client('instances').send(action, project: project_id, zone: zone, instance: instance_identity)
    rescue ::Google::Cloud::Error => e
      raise Foreman::WrappedException.new(e, 'Could not %s Google resource %s', action.to_s, resource_name)
    end

    def resource_client(resource_name)
      ::Google::Cloud::Compute.public_send(resource_name) do |config|
        config.credentials = @auth_json
      end
    end

    def all_projects
      %w[centos-cloud cos-cloud coreos-cloud debian-cloud opensuse-cloud
         rhel-cloud rhel-sap-cloud suse-cloud suse-sap-cloud
         ubuntu-os-cloud windows-cloud windows-sql-cloud].freeze
    end
  end
end
