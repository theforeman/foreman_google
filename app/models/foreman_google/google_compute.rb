module ForemanGoogle
  class GoogleCompute
    attr_reader :identity, :name, :hostname, :machine_type, :network_interfaces,
      :associate_external_ip, :image_id, :disks, :metadata

    # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
    def initialize(client:, zone:, identity: nil, name: nil, machine_type: nil,
                   network: 'default', associate_external_ip: nil, network_interfaces_list: [],
                   image_id: nil, volumes: [], user_data: nil)
      @client = client
      @zone = zone
      @identity = identity

      @name = parameterize_name(name)
      @hostname = @name
      @machine_type = machine_type
      @network_interfaces = construct_network(network, associate_external_ip, network_interfaces_list)
      @image_id = image_id
      @disks = load_disks(image_id, volumes)
      @metadata = construct_metadata(user_data)

      identity && load
    end
    # rubocop:enable Metrics/MethodLength, Metrics/ParameterLists

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
      persisted? && instance.status
    end

    def start
      raise Foreman::Exception('unable to start machine that is not persisted') unless persisted?
      @client.start(@zone, identity)
    end

    def stop
      raise Foreman::Exception('unable to stop machine that is not persisted') unless persisted?
      @client.stop(@zone, identity)
    end

    def to_s
    end

    def interfaces
      @network_interfaces
    end

    def interfaces_attributes=(attrs)
    end

    def volumes
      @disks
    end

    private

    def instance
      return unless identity
      @instance || load
    end

    def load
      @instance = @client.instance(@zone.split('/').last, identity)
    end

    def parameterize_name(name)
      name&.parameterize || "foreman_#{Time.now.to_i}"
    end

    def construct_network(network_name, associate_external_ip, network_interfaces_list)
      # handle network_interface for external ip
      # assign  ephemeral external IP address using associate_external_ip
      if ActiveModel::Type::Boolean.new.cast(associate_external_ip)
        network_interfaces_list = [{ network: 'global/networks/default' }] if network_interfaces_list.empty?
        access_config = { name: 'External NAT', type: 'ONE_TO_ONE_NAT' }

        # Note - no support for external_ip from foreman
        # access_config[:nat_ip] = external_ip if external_ip
        network_interfaces_list[0][:access_configs] = [access_config]
        return network_interfaces_list
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

    def load_disks(image_id, volumes)
      return [] if volumes.empty?
      image = load_image(image_id)

      volumes.first[:source_image] = image.name if image
      # TODO: Is OpenStruct enough to replace Fog::Compute::Google::Disk
      #       or do we need our own class?
      volumes.map.with_index do |vol_attrs, i|
        OpenStruct.new(**vol_attrs.merge(name: "#{@name}-disk#{i + 1}"))
      end
    end

    # Note - GCE only supports cloud-init for Container Optimized images and
    # for custom images with cloud-init setup
    def construct_metadata(user_data)
      return if user_data.blank?
      { items: [{ key: 'user-data', value: user_data }] }
    end
  end
end
