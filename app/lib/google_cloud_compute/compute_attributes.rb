module GoogleCloudCompute
  class ComputeAttributes
    attr_reader :name, :hostname, :machine_type, :network,
      :network_interfaces, :volumes, :image_id, :disks, :metadata

    def initialize(client, zone, attrs = {})
      @client = client
      @zone = zone

      @name = parameterize_name(attrs[:name])
      @hostname = @name
      @machine_type = attrs[:machine_type]
      @network = attrs[:network] || 'default'
      @network_interfaces = construct_network(@network, attrs[:associate_external_ip] || '0', attrs[:network_interfaces] || [])
      @image_id = attrs[:image_id]
      @volumes = construct_volumes(attrs[:image_id], attrs[:volumes])
      @metadata = construct_metadata(attrs[:user_data])
    end

    def hash_for_create
      {
        name: @name,
        machine_type: "zones/#{@zone}/machineTypes/#{@machine_type}",
        disks: @volumes.map.with_index { |vol, i| { source: "zones/#{@zone}/disks/#{vol[:name]}", boot: i.zero? } },
        network_interfaces: @network_interfaces,
        metadata: @metadata,
      }
    end

    private

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

    def construct_volumes(image_id, volumes = [])
      return [] if volumes.empty?
      image = load_image(image_id)

      new_vol_attrs = volumes.map.with_index do |vol_attrs, i|
        { name: "#{@name}-disk#{i + 1}",
          size_gb: vol_attrs[:size_gb]&.to_i }
      end

      new_vol_attrs.first[:source_image] = image&.self_link
      new_vol_attrs
    end

    # Note - GCE only supports cloud-init for Container Optimized images and
    # for custom images with cloud-init setup
    def construct_metadata(user_data)
      return if user_data.blank?
      { items: [{ key: 'user-data', value: user_data }] }
    end

    def load_image(image_id)
      return unless image_id

      image = @client.images.find { |img| img.id == image_id.to_i }
      raise ::Foreman::Exception, N_('selected image does not exist') if image.nil?
      image
    end
  end
end
