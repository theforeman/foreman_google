require 'foreman_google/google_compute_adapter'

module ForemanGoogle
  class GCE < ::ComputeResource
    def self.available?
      true
    end

    def self.provider_friendly_name
      'Google'
    end

    def user_data_supported?
      true
    end

    def self.model_name
      ComputeResource.model_name
    end

    def test_connection(options = {})
    end

    def to_label
    end

    def capabilities
      %i[image new_volume]
    end

    def zones
      client.zones.map(&:name)
    end
    alias_method :available_zones, :zones

    def zone
      url
    end

    def zone=(zone)
      self.url = zone
    end

    def networks
      client.networks.map(&:name)
    end

    def available_networks(_cluster_id = nil)
      client.networks.items
    end

    def machine_types
      client.machine_types(zone)
    end
    alias_method :available_flavors, :machine_types

    def disks
    end

    # def interfaces_attrs_name
    #   super # :interfaces
    # end

    # This should return interface compatible with Fog::Server
    # implemented by ForemanGoogle::Compute
    def find_vm_by_uuid(uuid)
      GoogleCompute.new(client: client, zone: zone, identity: uuid.to_s)
    end

    def destroy_vm(uuid)
    end

    def new_vm(args = {})
    end

    def create_volumes(args)
    end

    def create_vm(args = {})
      new_vm(args)
      create_volumes(args)
      # TBD
    end

    def vm_options(args)
    end

    def new_volume(attrs = {})
    end

    def normalize_vm_attrs(vm_attrs)
    end

    def console(uuid)
    end

    def associated_host(vm)
    end

    def available_images(filter: nil)
      client.images(filter: filter)
    end

    # ----# Google specific #-----

    def google_project_id
      client.project_id
    end

    private

    def client
      @client ||= ForemanGoogle::GoogleComputeAdapter.new(auth_json_string: password)
    end
  end
end
