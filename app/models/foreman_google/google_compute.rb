module ForemanGoogle
  class GoogleCompute
    attr_reader :identity

    def initialize(client:, zone:, identity: nil)
      @client = client
      @zone = zone
      @identity = identity
      identity && load
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
      persisted? && instance.status
    end

    def start
    end

    def stop
    end

    def to_s
    end

    def interfaces
    end

    def interfaces_attributes=(attrs)
    end

    def volumes
    end

    def volumes_attributes=(attrs)
    end

    private

    def instance
      return unless identity
      @instance || load
    end

    def load
      @instance = @client.instance(@zone.split('/').last, identity)
    end
  end
end
