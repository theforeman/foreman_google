require 'google/apis/compute_v1'

# TODO: enable back after https://github.com/stejskalleos/foreman_google/issues/21
# rubocop:disable Metrics/ClassLength
module ForemanGoogle
  class GoogleCompute
    attr_reader :identity, :name, :hostname, :machine_type, :network_interfaces, :volumes,
      :associate_external_ip, :image_id, :disks, :metadata

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def initialize(client:, zone:, identity: nil, args: {})
      @client = client
      @zone = zone
      @identity = identity

      @name = parameterize_name(args[:name])
      @hostname = @name
      @machine_type = args[:machine_type]
      @network_interfaces = construct_network(args[:network] || 'default', args[:associate_external_ip] || '0', args[:network_interfaces] || [])
      @image_id = args[:image_id]
      @volumes = construct_volumes(args[:image_id], args[:volumes])
      @metadata = construct_metadata(args[:user_data])

      identity && load
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

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

    def create_volumes
      @volumes.each do |volume|
        @client.insert_disk(@zone, volume)
      end
    end

    def wait_for_volumes
      @volumes.each do |disk|
        wait_for { @client.disk(@zone, disk[:name]).status == 'READY' }
      end
    end

    def destroy_volumes
      @volumes.each do |disk|
        @client.delete_disk(@zone, disk[:name])
      end
    end

    def create_instance
      args = {
        name: @name,
        machine_type: "zones/#{@zone}/machineTypes/#{@machine_type}",
        disks: @volumes.map.with_index { |vol, i| { source: "zones/#{@zone}/disks/#{vol[:name]}", boot: i.zero? } },
        network_interfaces: @network_interfaces,
        metadata: @metadata,
      }

      @client.insert_instance(@zone, args)
    end

    def set_disk_auto_delete
      @client.set_disk_auto_delete(@zone, @name)
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

    def wait_for
      timeout = 60
      duration = 0
      interval = 0.5

      start = Time.zone.now
      loop do
        break if yield

        raise "The specified wait_for timeout (#{timeout} seconds) was exceeded" if duration > timeout

        sleep(interval)
        duration = Time.zone.now - start
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
