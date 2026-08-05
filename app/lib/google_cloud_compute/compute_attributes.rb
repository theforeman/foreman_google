module GoogleCloudCompute
  class ComputeAttributes
    def initialize(client)
      @client = client
    end

    def for_new(args)
      name = parameterize_name(args[:name])
      base = new_base_attrs(name, args)
      base.merge(
        network_interfaces: construct_network(base[:network], base[:subnetwork], args[:zone],
          base[:associate_external_ip], args[:network_interfaces] || []),
        volumes: construct_volumes(name, args[:image_id], args[:volumes]),
        metadata: construct_metadata(args)
      )
    end

    def for_create(instance)
      {
        name: instance.name,
        machine_type: "zones/#{instance.zone}/machineTypes/#{instance.machine_type}",
        disks: instance.volumes.map.with_index { |vol, i| { source: "zones/#{instance.zone}/disks/#{vol.device_name}", boot: i.zero? } },
        network_interfaces: instance.network_interfaces,
        metadata: instance.metadata,
      }
    end

    def for_instance(instance)
      first_nic = instance.network_interfaces[0]
      attrs = instance_base_attrs(instance)
      attrs.merge(network: extract_resource_name(first_nic&.network),
        subnetwork: extract_resource_name(first_nic&.subnetwork),
        network_interfaces: instance.network_interfaces,
        volumes: instance.disks, metadata: instance.metadata)
    end

    private

    def parameterize_name(name)
      name&.parameterize || "foreman-#{Time.now.to_i}"
    end

    def new_base_attrs(name, args)
      { name: name, hostname: name, machine_type: args[:machine_type],
        network: args[:network] || 'default', subnetwork: args[:subnetwork],
        associate_external_ip: ActiveModel::Type::Boolean.new.cast(args[:associate_external_ip]),
        image_id: args[:image_id] }
    end

    def instance_base_attrs(instance)
      { name: instance.name, hostname: instance.name,
        creation_timestamp: instance.creation_timestamp.to_datetime,
        zone_name: instance.zone.split('/').last,
        machine_type: instance.machine_type }
    end

    def extract_resource_name(url)
      url&.split('/')&.last
    end

    def construct_network(network_name, subnetwork_name, zone, associate_external_ip, network_interfaces)
      network_interfaces = build_network_interfaces(network_name, associate_external_ip, network_interfaces)
      apply_subnetwork(network_interfaces, subnetwork_name, zone)
      network_interfaces
    end

    def build_network_interfaces(network_name, associate_external_ip, network_interfaces)
      if associate_external_ip
        network_interfaces = [{ network: "global/networks/#{network_name}" }] if network_interfaces.empty?
        network_interfaces[0][:access_configs] = [{ name: 'External NAT', type: 'ONE_TO_ONE_NAT' }]
        network_interfaces
      else
        network = "https://compute.googleapis.com/compute/v1/projects/#{@client.project_id}/global/networks/#{network_name}"
        [{ network: network }]
      end
    end

    def apply_subnetwork(network_interfaces, subnetwork_name, zone)
      return if subnetwork_name.blank?

      region = zone_to_region(zone)
      network_interfaces[0][:subnetwork] = "projects/#{@client.project_id}/regions/#{region}/subnetworks/#{subnetwork_name}"
    end

    def zone_to_region(zone)
      zone.to_s.split('-')[0..-2].join('-')
    end

    def load_image(image_id)
      return unless image_id

      @client.image(image_id.to_i)
    end

    def construct_volumes(vm_name, image_id, volumes = [])
      return [Google::Cloud::Compute::V1::AttachedDisk.new(disk_size_gb: 20)] if volumes.empty?

      image = load_image(image_id)

      attached_disks = volumes.map.with_index do |vol_attrs, i|
        name = "#{vm_name}-disk#{i + 1}"
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
  end
end
