require 'sshkit'
require 'forwardable'
require './rake/formatter'
require './rake/shellout'

class Remote
  # SSHkit mimic backend DSL with a bit reduced interface,
  # but also with a few enhancments.
  class DSL
    extend Forwardable
    attr_reader :backend, :default_command_options

    # Methods which are passed as is
    def_delegators  :backend, :make, :rake, :as, :with, :within,
                    :upload!, :download!

    # Customized delegated methods, they automatically inject
    # options into the call argument list.
    [:test, :capture, :execute].each do |method_name|
      define_method method_name do |*args|
        options_hash = args.extract_options!.merge!(options)
        backend.send(method_name, *args, options_hash).tap do |success|
          if options_hash[:finish_on_non_zero_exit] && !success
            ShellOut.finalize
            exit(1)
          end
        end
      end
    end

    def initialize(backend)
      @backend, @options = backend, default_command_options
    end

    def default_command_options
      @default_command_options ||= {
        finish_on_non_zero_exit: true,
        raise_on_non_zero_exit: false,
        show_exit_status: true,
        show_start_message: true,
        show_uuid: true
      }
    end

    # Provide option setting DSL method
    def options(*args)
      # Extract_options method pacthes array to return first hash
      # (patched in sshkit)
      command_options = args.extract_options!
      command_options.empty? ? @options : @options = default_command_options.merge(command_options)
    end
  end

  attr_reader :ssh_options

  # Cache for sshkit backends
  @@backend_cache = {}
  @@output_format = :shellout

  def initialize(ssh_options={})
    @ssh_options = ssh_options
  end

  # Perform operation on a remote node
  def ssh(options_hash, &block)
    backend = DSL.new(fetch_backend(options_hash))
    backend.instance_exec(&block) if block
  end

  class << self
    extend Forwardable
    def_delegators :'SSHKit.config', :output_verbosity, :output_verbosity=
  end

  private

  # Retrieve backed for a given host from cache
  def fetch_backend(options_hash)
    host = SSHKit::Host.new(options_hash)
    if @@backend_cache[host]
      @@backend_cache[host]
    else
      SSHKit.config.use_format(:shellout)
      host.ssh_options = ssh_options
      host.user ||= 'root' # figure this out, current user?
      klass = host.local? ? :Local : :Netssh
      @@backend_cache[host] = SSHKit::Backend.const_get(klass).new(host)
    end
  end
end
