# rubocop:disable Rails/SkipsModelValidations, Metrics/ClassLength
require 'faraday'
require 'google/cloud/compute/v1/zones/credentials'

module ForemanGoogle
  class GoogleComputeAdapter
    def initialize(auth_json_string:, connection_options: {})
      @auth_json = JSON.parse(auth_json_string)
      @connection_options = connection_options
    end

    def project_id
      @auth_json['project_id']
    end

    # ------ RESOURCES ------

    def insert_instance(zone, attrs = {})
      response = resource_client('instances').insert(project: project_id, zone: zone, instance_resource: attrs)
      operation_attrs = { zone: zone, operation: response.operation.id.to_s }

      wait_for do
        get('zone_operations', **operation_attrs).status == :DONE
      end

      e = get('zone_operations', **operation_attrs).error

      return response unless e

      raise ::Google::Cloud::Error, e.errors.first.message
    end

    # Returns an Google::Instance identified by instance_identity within given zone.
    # @param zone [String] eighter full url or just zone name
    # @param instance_identity [String] eighter an instance name or its id
    def instance(zone, instance_identity)
      get('instances', instance: instance_identity, zone: zone)
    end

    def instances(zone, **attrs)
      list('instances', zone: zone, **attrs)
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
      manage_instance(:start, zone: zone, instance: instance_identity)
    end

    def stop(zone, instance_identity)
      manage_instance(:stop, zone: zone, instance: instance_identity)
    end

    def delete_instance(zone, instance_identity)
      manage_instance(:delete, zone: zone, instance: instance_identity)
    end

    # Setting filter to '(deprecated.state != "DEPRECATED") AND (deprecated.state != "OBSOLETE")'
    # doesn't work and returns empty array, no idea what is happening there
    def images(filter: nil)
      projects = [project_id] + all_projects
      all_images = projects.map { |project| list_images(project, filter: filter) }
      all_images.flatten.reject(&:deprecated)
    end

    def image(uuid)
      images.find { |img| img.id == uuid }
    end

    def insert_disk(zone, disk_attrs = {})
      insert('disks', zone, disk_resource: disk_attrs)
    end

    def disk(zone, name)
      get('disks', disk: name, zone: zone)
    end

    def delete_disk(zone, disk_name)
      delete('disks', zone, disk: disk_name)
    end

    def set_disk_auto_delete(zone, instance_identity)
      instance = instance(zone, instance_identity)
      instance.disks.each do |disk|
        manage_instance :set_disk_auto_delete, zone: zone,
          device_name: disk.device_name,
          instance: instance_identity,
          auto_delete: true
      end
    end

    def serial_port_output(zone, instance_identity)
      manage_instance(:get_serial_port_output, zone: zone, instance: instance_identity)
    end

    def wait_for
      timeout = 60
      duration = 0
      start = Time.zone.now

      loop do
        break if yield

        raise "The specified wait_for timeout (#{timeout} seconds) was exceeded" if duration > timeout

        sleep(1)
        duration = Time.zone.now - start
      end

      { duration: duration }
    end

    private

    def list(resource_name, **opts)
      response = resource_client(resource_name).list(project: project_id, **opts).response
      response.items
    rescue ::Google::Cloud::Error => e
      raise Foreman::WrappedException.new(e, 'Cannot list Google resource %s', resource_name)
    end

    def get(resource_name, **opts)
      resource_client(resource_name).get(project: project_id, **opts)
    rescue Google::Cloud::NotFoundError => e
      Foreman::Logging.exception("Could not fetch Google instance [#{opts[:instance]}]", e)
      raise ActiveRecord::RecordNotFound
    rescue ::Google::Cloud::Error => e
      raise Foreman::WrappedException.new(e, 'Could not fetch Google resource %s', resource_name)
    end

    def insert(resource_name, zone, **opts)
      resource_client(resource_name).insert(project: project_id, zone: zone, **opts)
    rescue ::Google::Cloud::Error => e
      raise Foreman::WrappedException.new(e, 'Could not create Google resource %s', resource_name)
    end

    def delete(resource_name, zone, **opts)
      resource_client(resource_name).delete(project: project_id, zone: zone, **opts)
    rescue ::Google::Cloud::Error => e
      raise Foreman::WrappedException.new(e, 'Could not delete Google resource %s', resource_name)
    end

    def list_images(project, **opts)
      resource_name = 'images'
      resource_client(resource_name).list(project: project, **opts).to_a
    rescue ::Google::Cloud::Error => e
      raise Foreman::WrappedException.new(e, 'Cannot list Google resource %s', resource_name)
    end

    def manage_instance(action, **opts)
      resource_client('instances').send(action, project: project_id, **opts)
    rescue ::Google::Cloud::Error => e
      raise Foreman::WrappedException.new(e, 'Could not %s Google resource %s', action.to_s, resource_name)
    end

    def resource_client(resource_name)
      client = ::Google::Cloud::Compute.public_send(resource_name) do |config|
        config.credentials = credentials
      end

      configure_http_proxy(client, resource_name)
      client
    end

    def credentials
      return @auth_json unless @connection_options[:proxy]

      @credentials ||= ::Google::Cloud::Compute::V1::Zones::Credentials.new(
        @auth_json,
        connection_builder: -> { faraday_connection }
      )
    end

    def faraday_connection
      Faraday.new do |connection|
        configure_faraday_connection(connection)
        connection.adapter :net_http
      end
    end

    def configure_http_proxy(client, resource_name)
      return unless @connection_options[:proxy]

      # The generated Compute clients don't expose their REST transport options.
      service_stub = client.instance_variable_get("@#{resource_name}_stub")
      rest_client_stub = service_stub.instance_variable_get(:@client_stub)
      connection = rest_client_stub.instance_variable_get(:@connection)
      configure_faraday_connection(connection)
    end

    def configure_faraday_connection(connection)
      connection.proxy = @connection_options[:proxy]
      connection.ssl.cert_store = @connection_options[:ssl_cert_store] if @connection_options[:ssl_cert_store]
    end

    def all_projects
      %w[centos-cloud cos-cloud coreos-cloud debian-cloud opensuse-cloud
         rhel-cloud rhel-sap-cloud suse-cloud suse-sap-cloud
         ubuntu-os-cloud windows-cloud windows-sql-cloud].freeze
    end
  end
end
# rubocop:enable Rails/SkipsModelValidations, Metrics/ClassLength
