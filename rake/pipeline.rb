require 'hashie'
require 'logger'
require './rake/remote'

class PipeLine
  attr_reader :basedir, :scripts, :env
  attr_accessor :default_env_select
  attr_writer :ssh_options

  def initialize(basedir, scripts, env)
    @env = fetch_env(env)
    @basedir, @scripts = basedir, Hashie::Mash.new(scripts)
    @default_env_select = [
      :compose,
      :debug_level,
      :artifact_dir
    ]
    Remote.output_verbosity = logger(self.env.debug_level)
  end

  def ssh_options
    @ssh_options ||= {
      keys: %w(/root/.ssh/busybee),
      auth_methods: %w(publickey)
    }
  end

  # exec provide Remote instance which actually provides 
  # Netssh and Local backends.
  def exec
    @exec ||= Remote.new(ssh_options)
  end

  # Selected environment to pass to the remotes
  def env_select(*args)
    list = default_env_select + args
    selection = {}
    env.keys.each do |k|
      selection[k.to_s.upcase] = env[k] if list.include?(k.to_sym)
    end
    selection
  end

  # Fetch script options
  def script_options(script)
    mash = script_defaults.merge(scripts[script])
    mash.tap do |m|
      m[:path] = File.join(basedir, m[:script])
      m[:within] = File.join(basedir, m[:package])
      m[:env]  = env_select(*m[:use_env])
    end
  end

  def script_defaults
    @script_defaults ||= Hashie::Mash.new({
      args: [],
      use_env: []
    })
  end

  private

  # Creates env mash instance, which is accessible like env['key'],
  # env[:key] or env.key.
  def fetch_env(env)
    env.inject(Hashie::Mash.new) do |ac, var|
      var, defv = Array(var)
      val = ENV[var.to_s.upcase]
      ac[var] = val.to_s.empty? ? defv : val
      ac
    end
  end

  def logger(verbosity)
    case verbosity
    when String
      verbosity.match(/^\d/) ? verbosity.to_i : Logger.const_get(verbosity.upcase)
    when Integer
      verbosity
    else
      Logger.const_get(verbosity.upcase)
    end
  end
end
