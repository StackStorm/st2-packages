require 'hashie'
require 'logger'
require './rake/remote'

class PipeLine
  attr_accessor :default_env_select
  attr_writer :ssh_options

  USE_ENVIRONMENT = [
    :buildnode,
    :compose,
    [:artifact_dir, '/root/build'],       # later change with mktmp ?
    [:debug_level, 1],
    [:st2_python, 0],
    [:st2_python_version, '2.7.10'],
    [:st2_python_relase, '1'],
  ].freeze

  def initialize
    @default_env_select = [
      :compose,
      :debug_level,
      :artifact_dir
    ]
    Remote.output_verbosity = logger(env.debug_level)
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

  # Pipeline env hash (mash), ie accessible like env['key'], env[:key] or env.key
  def env
    @env ||= USE_ENVIRONMENT.inject(Hashie::Mash.new) do |ac, var|
      var, defv = Array(var)
      val = ENV[var.to_s.upcase]
      ac[var] = val.to_s.empty? ? defv : val
      ac
    end
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

  private

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
