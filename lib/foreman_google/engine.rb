module ForemanGoogle
  class Engine < ::Rails::Engine
    isolate_namespace ForemanGoogle
    engine_name 'foreman_google'

    # Add any db migrations
    initializer 'foreman_google.load_app_instance_data' do |app|
      ForemanGoogle::Engine.paths['db/migrate'].existent.each do |path|
        app.config.paths['db/migrate'] << path
      end
    end

    initializer 'foreman_google.register_plugin', before: :finisher_hook do |_app|
      Foreman::Plugin.register :foreman_google do
        requires_foreman '>= 2.4.0'
        register_global_js_file 'global'

        in_to_prepare do
          compute_resource(ForemanGoogle::GCE)
        end
      end
    end

    # Include concerns in this config.to_prepare block
    config.to_prepare do
      require 'google/cloud/compute/v1'

      ::Host::Managed.include ForemanGoogle::HostManagedExtensions
      ::Api::V2::ComputeResourcesController.include ForemanGoogle::Api::V2::ComputeResourcesControllerExtensions::ApipieExtensions
      Google::Cloud::Compute::V1::AttachedDisk.include GoogleExtensions::AttachedDisk
    rescue StandardError => e
      Rails.logger.warn "ForemanGoogle: skipping engine hook (#{e})"
    end

    rake_tasks do
      Rake::Task['db:seed'].enhance do
        ForemanGoogle::Engine.load_seed
      end
    end

    initializer 'foreman_google.register_gettext', after: :load_config_initializers do |_app|
      locale_dir = File.join(File.expand_path('../..', __dir__), 'locale')
      locale_domain = 'foreman_google'
      Foreman::Gettext::Support.add_text_domain locale_domain, locale_dir
    end
  end
end
