require 'sshkit'
require 'forwardable'
require './rake/formatter'
require './rake/shellout'

class Remote
  # SSHkit mimic backend DSL with a bit reduced interface,
  # but also with a few enhancments.
  class SSHKitDSL
    extend Forwardable
    attr_reader :backend, :default_command_options

    # Methods which are passed as is
    def_delegators  :backend, :as, :with, :within, :upload!, :download!

    # Customized delegated methods, they automatically inject
    # options into the call argument list.
    [:test, :capture, :execute].each do |method_name|
      define_method method_name do |*args|
        command_options = args.extract_options!.merge!(command)
        begin
          backend.send(method_name, *args, command_options)
        rescue SSHKit::Command::Failed
          ShellOut.flush
          Thread.main.send(:raise, SystemExit.new(false))
        end
      end
    end

    def make(commands=[], options={})
      execute :make, commands, options
    end

    def rake(commands=[], options={})
      execute :rake, commands, options
    end

    def initialize(backend)
      @backend, @command = backend, default_command_options
    end

    def default_command_options
      @default_command_options ||= {
        show_exit_status: true,
        show_start_message: true,
        show_uuid: true
      }
    end

    # Command options settings passed through to sshkit DSL methods
    def command(*args)
      # Extract_options method pacthes array to return first hash
      # (patched in sshkit)
      command_options = args.extract_options!
      command_options.empty? ? @command : @command = default_command_options.merge(command_options)
    end
  end

  attr_reader :options, :ssh_options
  alias :opts :options

  # Cache for sshkit backends
  @@backend_cache = {}

  def initialize(options, ssh_options={})
    @options, @ssh_options = options, ssh_options
  end

  # Perform operation on a remote node in SSHKitDSL wrapper
  def run(host_arg_or_hash, &block)
    wrapper = SSHKitDSL.new(fetch_backend(host_arg_or_hash))
    wrapper.instance_exec(options, &block) if block
  end

  class << self
    extend Forwardable
    def_delegators :'SSHKit.config', :output_verbosity, :output_verbosity=
  end

  private

  # Retrieve backed for a given host from cache
  def fetch_backend(host_arg_or_hash)
    host = SSHKit::Host.new(host_arg_or_hash)
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
