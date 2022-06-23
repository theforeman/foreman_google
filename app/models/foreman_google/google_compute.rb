require 'google/apis/compute_v1'

# TODO: enable back after https://github.com/stejskalleos/foreman_google/issues/21
# rubocop:disable Metrics/ClassLength
module ForemanGoogle
  class GoogleCompute
    attr_reader :identity, :name, :hostname, :creation_timestamp, :machine_type, :network_interfaces, :volumes,
      :associate_external_ip, :network, :zone_name, :image_id, :disks, :metadata

    def initialize(client:, zone:, identity: nil, instance: nil, args: {})
      @client = client
      @zone = zone
      @identity = identity
      @instance = instance

      load if identity && instance.nil?

      # TODO: Following parameters should be in separate attribute class
      # https://github.com/stejskalleos/foreman_google/issues/21
      if @instance
        load_instance_vars
      else
        load_new_vars(args)
      end
    end

    def persisted?
      !!identity
    end

    def ready?
      status == 'RUNNING'
    end

    def reload
      return unless identity
      load
      self
    end

    # @returns [String] one of PROVISIONING, STAGING, RUNNING, STOPPING, SUSPENDING, SUSPENDED, REPAIRING, and TERMINATED
    # if nil, instance is not persisted as VM on GCE
    def status
      persisted? && @instance.status
    end
    alias_method :state, :status

    def start
      raise Foreman::Exception('unable to start machine that is not persisted') unless persisted?
      @client.start(@zone, identity)
    end

    def stop
      raise Foreman::Exception('unable to stop machine that is not persisted') unless persisted?
      @client.stop(@zone, identity)
    end

    def to_s
      @instance&.name
    end

    def interfaces
      @network_interfaces
    end

    def create_volumes
      @volumes.each do |vol|
        @client.insert_disk(@zone, vol.insert_attrs)
        wait_for { @client.disk(@zone, vol.device_name).status == 'READY' }
      end
    end

    def destroy_volumes
      @volumes.each do |volume|
        @client.delete_disk(@zone, volume.device_name)
      end
    end

    def create_instance
      args = {
        name: @name,
        machine_type: "zones/#{@zone}/machineTypes/#{@machine_type}",
        disks: @volumes.map.with_index { |vol, i| { source: "zones/#{@zone}/disks/#{vol.device_name}", boot: i.zero? } },
        network_interfaces: @network_interfaces,
        metadata: @metadata,
      }

      @client.insert_instance(@zone, args)
    end

    def set_disk_auto_delete
      @client.set_disk_auto_delete(@zone, @name)
    end

    def pretty_machine_type
      return unless @instance
      @instance.machine_type.split('/').last
    end

    def vm_ip_address
      return if @instance.network_interfaces.empty?

      @instance.network_interfaces.first.access_configs.first&.nat_i_p
    end
    alias_method :public_ip_address, :vm_ip_address

    def private_ip_address
      return unless @instance.network_interfaces.any?

      @instance.network_interfaces.first.network_i_p
    end

    def pretty_image_name
      return unless @instance.disks.any?

      disk_name = @instance.disks.first.device_name
      image_name = @client.disk(@zone_name, disk_name).source_image

      image_name.split('/').last
    end

    def volumes_attributes=(_attrs)
    end

    def serial_port_output
      @client.serial_port_output(@zone, @identity)&.contents
    end

    def ip_addresses
      [vm_ip_address, private_ip_address]
    end

    def wait_for(&block)
      @client.wait_for(&block)
    end

    private

    def load
      @instance = @client.instance(@zone.split('/').last, identity)
    end

    def parameterize_name(name)
      name&.parameterize || "foreman-#{Time.now.to_i}"
    end

    def construct_network(network_name, associate_external_ip, network_interfaces)
      # handle network_interface for external ip
      # assign  ephemeral external IP address using associate_external_ip
      if ActiveModel::Type::Boolean.new.cast(associate_external_ip)
        network_interfaces = [{ network: 'global/networks/default' }] if network_interfaces.empty?
        access_config = { name: 'External NAT', type: 'ONE_TO_ONE_NAT' }

        # Note - no support for external_ip from foreman
        # access_config[:nat_ip] = external_ip if external_ip
        network_interfaces[0][:access_configs] = [access_config]
        return network_interfaces
      end

      network = "https://compute.googleapis.com/compute/v1/projects/#{@client.project_id}/global/networks/#{network_name}"
      [{ network: network }]
    end

    def load_image(image_id)
      return unless image_id

      image = @client.images.find { |img| img.id == image_id.to_i }
      raise ::Foreman::Exception, N_('selected image does not exist') if image.nil?
      image
    end

    def construct_volumes(image_id, volumes = [])
      return [Google::Cloud::Compute::V1::AttachedDisk.new(disk_size_gb: 20)] if volumes.empty?

      image = load_image(image_id)

      attached_disks = volumes.map.with_index do |vol_attrs, i|
        name = "#{@name}-disk#{i + 1}"
        size = (vol_attrs[:size_gb] || vol_attrs[:disk_size_gb]).to_i

        Google::Cloud::Compute::V1::AttachedDisk.new(device_name: name, disk_size_gb: size)
      end

      attached_disks.first.source = image&.self_link if image&.self_link
      attached_disks
    end

    # Note - GCE only supports cloud-init for Container Optimized images and
    # for custom images with cloud-init setup
    def construct_metadata(args)
      ssh_keys = { key: 'ssh-keys', value: "#{args[:username]}:#{args[:public_key]}" }

      return { items: [ssh_keys] } if args[:user_data].blank?

      { items: [ssh_keys, { key: 'user-data', value: args[:user_data] }] }
    end

    # rubocop:disable Metrics/AbcSize
    def load_instance_vars
      @name = @instance.name
      @hostname = @name
      @creation_timestamp = @instance.creation_timestamp.to_datetime
      @zone_name = @instance.zone.split('/').last
      @machine_type = @instance.machine_type
      @network = @instance.network_interfaces[0].network.split('/').last
      @network_interfaces = @instance.network_interfaces
      @volumes = @instance.disks
      @metadata = @instance.metadata
    end
    # rubocop:enable Metrics/AbcSize

    def load_new_vars(args)
      @name = parameterize_name(args[:name])
      @hostname = @name
      @machine_type = args[:machine_type]
      @network_interfaces = construct_network(args[:network] || 'default', args[:associate_external_ip] || '0', args[:network_interfaces] || [])
      @image_id = args[:image_id]
      @volumes = construct_volumes(args[:image_id], args[:volumes])
      @metadata = construct_metadata(args)
    end
  end
end
# rubocop:enable Metrics/ClassLength
