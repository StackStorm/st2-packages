require 'tempfile'

module Pipeline
  module Options
    # Environment loader and Pipeline options setter
    class SetEnvLoaderDSL
      def initialize(mash_context, mash_global=nil)
        @context, @global = mash_context, mash_global
      end

      # Sets option from env
      def env(var, default=nil, opts=nil)
        value, _ = parse_envpass_value(var, default, opts)
        value.tap do
          context.assign_property(var, value) if value
        end
      end

      # Sets option from env as well as corresponding options env[var]
      def envpass(var, default=nil, opts=nil)
        value, opts = parse_envpass_value(var, default, opts)
        value.tap do
          if value
            # Set context option as
            context.assign_property(var, value)
            # well as populate context[:env]
            var = var.upcase if opts[:upcase]
            context[:env] ||= Hashie::Mash.new
            context[:env].merge!({var => value})
          end
        end
      end

      def make_tmpname(basename='', tmpdir=Dir.tmpdir)
        Dir::Tmpname.make_tmpname File.join(tmpdir, basename), nil
      end

      def method_missing(method_name, *args)
        # setter invoked
        unless args.empty?
          value = args.size < 2 ? args.pop : args
          context.assign_property(method_name, value)
        else
          if global && global.respond_to?(method_name)
            global.send(method_name)
          end
        end
      end

      private
      attr_reader :context, :global

      # Parse arguments for env, envpass methods
      def parse_envpass_value(var, default, opts)
        opts, default = default, nil if default.is_a?(Hash)
        defs = {upcase: true}
        opts = defs.merge(opts || {})
        var  = opts[:from] if opts[:from]
        value = opts[:upcase] ? ENV[var.to_s.upcase] : ENV[var.to_s]
        # set value nil for an empty env var
        value = nil if value.to_s.empty?
        [value || default, opts]
      end
    end

    # Store options into mash either global or context specific.
    def pipeopts(context_name=nil, &block)
      global = pipe_options
      context = context_pipe_options[context_name]
      args = context_name.nil? ? [global] : [context, global]
      # Assign or return pipe options
      unless block.nil?
        SetEnvLoaderDSL.new(*args).instance_exec(&block)
      else
        args.first
      end
    end

    private

    def pipe_options
      @pipe_options ||= Hashie::Mash.new
    end

    def context_pipe_options
      @context_pipe_options ||= Hash.new {|h, k| h[k] =  Hashie::Mash.new}
    end
  end
end
