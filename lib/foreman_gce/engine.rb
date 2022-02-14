module ForemanGce
  class Engine < ::Rails::Engine
    isolate_namespace ForemanGce
    engine_name 'foreman_gce'

    # Add any db migrations
    initializer 'foreman_gce.load_app_instance_data' do |app|
      ForemanGce::Engine.paths['db/migrate'].existent.each do |path|
        app.config.paths['db/migrate'] << path
      end
    end

    initializer 'foreman_gce.register_plugin', before: :finisher_hook do |_app|
      Foreman::Plugin.register :foreman_gce do
        requires_foreman '>= 2.4.0'

        # Add Global files for extending foreman-core components and routes
        register_global_js_file 'global'

        # Add permissions
        security_block :foreman_gce do
          permission :view_foreman_gce, { 'foreman_gce/example' => [:new_action],
                                          :react => [:index] }
        end

        # Add a new role called 'Discovery' if it doesn't exist
        role 'ForemanGce', [:view_foreman_gce]

        # add menu entry
        sub_menu :top_menu, :plugin_template, icon: 'pficon pficon-enterprise', caption: N_('Plugin Template'), after: :hosts_menu do
          menu :top_menu, :welcome, caption: N_('Welcome Page'), engine: ForemanGce::Engine
          menu :top_menu, :new_action, caption: N_('New Action'), engine: ForemanGce::Engine
        end

        # add dashboard widget
        widget 'foreman_gce_widget', name: N_('Foreman plugin template widget'), sizex: 4, sizey: 1
      end
    end

    # Include concerns in this config.to_prepare block
    config.to_prepare do
      Host::Managed.include ForemanGce::HostExtensions
      HostsHelper.include ForemanGce::HostsHelperExtensions
    rescue StandardError => e
      Rails.logger.warn "ForemanGce: skipping engine hook (#{e})"
    end

    rake_tasks do
      Rake::Task['db:seed'].enhance do
        ForemanGce::Engine.load_seed
      end
    end

    initializer 'foreman_gce.register_gettext', after: :load_config_initializers do |_app|
      locale_dir = File.join(File.expand_path('../..', __dir__), 'locale')
      locale_domain = 'foreman_gce'
      Foreman::Gettext::Support.add_text_domain locale_domain, locale_dir
    end
  end
end
