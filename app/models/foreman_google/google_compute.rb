require 'google/apis/compute_v1'

module ForemanGoogle
  class GoogleCompute
    attr_reader :identity, :name, :hostname, :machine_type, :network,
      :network_interfaces, :volumes, :image_id, :disks, :metadata

    def initialize(client:, zone:, identity: nil, instance: nil, args: {})
      @client = client
      @zone = zone
      @identity = identity
      @instance = instance
      @new_args = GoogleCloudCompute::ComputeAttributes.new(@client, @zone, args)

      instance_variables
      load if identity && !!!instance
    end

    def instance_variables
      source = !@instance.nil? ? @instance : @new_args

      @name = source.name
      @hostname = source.name
      @machine_type = source.machine_type
      @network = source.network
      @network_interfaces = source.network_interfaces
      @image_id = source.image_id
      @volumes = source.volumes
      @metadata = source.metadata
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
      @client.insert_instance(@zone, @new_args.hash_for_create)
    end

    def set_disk_auto_delete
      @client.set_disk_auto_delete(@zone, @name)
    end

    def pretty_machine_type
      @instance.machine_type.split('/').last
    end

    private

    def load
      @instance = @client.instance(@zone.split('/').last, identity)
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
