require 'hashie'
require 'logger'
require 'rake'
require './rake/pipeline_options'
require './rake/remote'

module Pipeline
  module Rake
    module TaskDSL
      def short_name
        name.split(':', 2).pop
      end
    end
  end
end

module Pipeline
  include Pipeline::Options

  # Invoke our sshkit remote wrapper with merged options
  def pipeline(context_name=nil, &block)
    if block
      options = pipe_options.dup
      context_options = context_pipe_options[context_name]
      options.merge!(context_options) unless context_name.nil?
      ssh_options = _ssh_options(options.ssh_options)
      sshkit_wrapper(options, ssh_options).instance_exec(&block)
    end
  end

  def self.included(includer)
    ::Rake::Task.send(:include, Rake::TaskDSL)
  end

  private

  # somehow bothering method missing, using dash
  def _ssh_options(mash)
    (mash || {}).inject({}) {|hash, (k, v)| hash[k.to_sym] = v; hash}
  end

  # Get our sshkit wrapper (sshkit methods are accessible in ssh method DSL)
  def sshkit_wrapper(options, ssh_options)
    Remote.new(options, ssh_options).tap do
      Remote.output_verbosity = logger(options.debug_level)
    end
  end

  def logger(verbosity)
    if verbosity.is_a?(String) && verbosity.match(/^\d/)
      verbosity = verbosity.to_i
    end
    verbosity.is_a?(Integer) ? verbosity : Logger.const_get(verbosity.upcase)
  end
end

include Pipeline
