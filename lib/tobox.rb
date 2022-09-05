# frozen_string_literal: true

require "sequel"

require_relative "tobox/version"

require "mutex_m"

module Tobox
  class Error < StandardError; end

  module Plugins
    @plugins = {}
    @plugins.extend(Mutex_m)

    # Loads a plugin based on a name. If the plugin hasn't been loaded, tries to load
    # it from the load path under "httpx/plugins/" directory.
    #
    def self.load_plugin(name)
      h = @plugins
      unless (plugin = h.synchronize { h[name] })
        require "tobox/plugins/#{name}"
        raise "Plugin #{name} hasn't been registered" unless (plugin = h.synchronize { h[name] })
      end
      plugin
    end

    # Registers a plugin (+mod+) in the central store indexed by +name+.
    #
    def self.register_plugin(name, mod)
      h = @plugins
      h.synchronize { h[name] = mod }
    end
  end
end

require_relative "tobox/configuration"
require_relative "tobox/fetcher"
require_relative "tobox/worker"
require_relative "tobox/pool"
require_relative "tobox/application"
