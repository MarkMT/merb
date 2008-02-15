#---
# require 'merb' must happen after Merb::Config is instantiated
require 'rubygems'
require 'set'
require 'fileutils'
require 'socket'

$LOAD_PATH.unshift File.dirname(__FILE__) unless
  $LOAD_PATH.include?(File.dirname(__FILE__)) ||
  $LOAD_PATH.include?(File.expand_path(File.dirname(__FILE__)))

require 'merb-core/autoload'
require 'merb-core/server'
require 'merb-core/core_ext'
require 'merb-core/gem_ext/erubis'
require 'merb-core/logger'
require 'merb-core/version'
require 'merb-core/controller/mime'
require 'merb-core/vendor/facets'

begin
  require "json/ext"
rescue LoadError
  require "json/pure"
end

module Merb
  class << self

    # ==== Parameters
    # argv<String, Hash>::
    #   The config arguments to start Merb with. Defaults to +ARGV+.
    def start(argv=ARGV)
      if Hash === argv
        Merb::Config.setup(argv)
      else
        Merb::Config.parse_args(argv)
      end
      Merb.environment = Merb::Config[:environment]
      Merb.root = Merb::Config[:merb_root]
      Merb::Server.start(Merb::Config[:port], Merb::Config[:cluster])
    end

    attr_accessor :environment, :load_paths, :adapter
    Merb.load_paths = Hash.new { [Merb.root] } unless Merb.load_paths.is_a?(Hash)

    # This is the core mechanism for setting up your application layout
    # merb-core won't set a default application layout, but merb-more will
    # use the app/:type layout that is in use in Merb 0.5.
    #
    # ==== Parameters
    # type<Symbol>:: The type of path being registered (i.e. :view)
    # path<String>:: The full path
    # file_glob<String>::
    #   A glob that will be used to autoload files under the path
    def push_path(type, path, file_glob = "**/*.rb")
      enforce!(type => Symbol)
      load_paths[type] = [path, file_glob]
    end

    # ==== Parameters
    # type<Symbol>:: The type of path to retrieve directory for, e.g. :view.
    def dir_for(type)  Merb.load_paths[type].first end

    # The pattern with which to match files within the type directory.
    #
    # ==== Parameters
    # type<Symbol>:: The type of path to retrieve glob for, e.g. :view.
    def glob_for(type) Merb.load_paths[type][1]    end

    # ==== Returns
    # String::
    #   The Merb root path.
    def root()          @root || Merb::Config[:merb_root] || Dir.pwd  end

    # ==== Parameters
    # value<String>:: Path to the root directory.
    def root=(value)    @root = value                                 end

    # ==== Parameters
    # path<String>::
    #   The relative path (or list of path components) to a directory under the
    #   root of the application.
    #
    # ==== Returns
    # String:: The full path including the root.
    #
    # ==== Examples
    #   Merb.root = "/home/merb/app"
    #   Merb.path("images") # => "/home/merb/app/images"
    #   Merb.path("views", "admin") # => "/home/merb/app/views/admin"
    #---
    # @public
    def root_path(*path) File.join(root, *path)                       end

    # Logger settings
    attr_accessor :logger

    # ==== Returns
    # String::
    #   The path to the log file. If this Merb instance is running as a daemon
    #   this will return +STDOUT+.
    def log_file
      if Merb::Config[:log_file]
        Merb::Config[:log_file]
      elsif $TESTING
        log_path / "merb_test.log"
      elsif !(Merb::Config[:daemonize] || Merb::Config[:cluster] )
        STDOUT
      else
        log_path / "merb.#{Merb::Config[:port]}.log"
      end
    end

    # ==== Returns
    # String:: The directory that contains the log file.
    def log_path
      if Merb::Config[:log_file]
        File.dirname(Merb::Config[:log_file])
      else
        Merb.root_path("log")
      end
    end

    # ==== Returns
    # String:: The root directory of the Merb framework.
    def framework_root()  @framework_root ||= File.dirname(__FILE__)  end

    # Allows flat apps by setting no default framework directories and yielding
    # a Merb::Router instance. This is optional since the router will
    # automatically configure the app with default routes.
    def flat!
      Merb::Config[:framework] = {}

      Merb::Router.prepare do |r|
        yield(r) if block_given?
        r.default_routes
      end
    end

    # Set up default variables under Merb
    attr_accessor :generator_scope, :klass_hashes
    Merb.generator_scope = [:merb_default, :merb, :rspec]
    Merb.klass_hashes = []

    attr_reader :registered_session_types

    # ==== Parameters
    # name<~to_s>:: Name of the session type to register.
    # file<String>:: The file that defines this session type.
    # description<String>:: An optional description of the session type.
    def register_session_type(name, file, description = nil)
      @registered_session_types ||= Dictionary.new
      @registered_session_types[name] = {
        :file => file,
        :description => (description || "Using #{name} sessions")
      }
    end

    attr_accessor :frozen

    # ==== Returns
    # Boolean:: True if Merb is running via script/frozen-merb or other freezer.
    def frozen?
      @frozen
    end

    # Used by script/frozen-merb and other freezers to mark Merb as frozen.
    def frozen!
      @frozen = true
    end

  end

end
