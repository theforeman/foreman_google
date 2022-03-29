module ForemanGoogle
  # This module prepends core paths so view for gce takes precedence over core ones
  # This module NEEDS to get deleted once the core support for gce is dropped.
  # or this plugin is merged to core
  module TemporaryPrependPath
    extend ActiveSupport::Concern

    included do
      before_action :prepare_views
    end

    def prepare_views
      prepend_view_path ForemanGoogle::Engine.root.join('app', 'views')
    end
  end
end
