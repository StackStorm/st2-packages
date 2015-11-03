module Pipeline
  module Options
    # Environment loader and Pipeline options setter
    class SetEnvLoaderDSL
      def initialize(mash_context, mash_global=nil)
        @context, @global = mash_context, mash_global
      end

      # Sets option from env
      def env(var, default=nil, opts=nil)
        value = parse_setenv_value(var, default, opts)
        value.tap do
          context.assign_property(var, value) if value
        end
      end

      # Sets option from env as well as corresponding options env[var]
      def set(var, default=nil, opts=nil)
        value = env(var, default, opts)
        value.tap do
          if value
            context[:env] ||= Hashie::Mash.new
            context[:env].merge!({var => value})
          end
        end
      end

      def make_tmpname(basename='', tmpdir=Dir.tmpdir)
        Dir::Tmpname.make_tmpname File.join(tmpdir, basename), nil
      end

      def method_missing(method_name, *args)
        # Substitute values from global context
        if global && global.respond_to?(method_name)
          global.send(method_name)
        else
          context.assign_property(method_name, *args)
        end
      end

      # There's only context saved in @mash, this means our context is global.
      def global_context?
        global.nil?
      end

      private
      attr_reader :context, :global

      # Parse arguments for env, set methods
      def parse_setenv_value(var, default, opts)
        opts, default = default, nil if default.is_a?(Hash)
        defs = {upcase: true}
        opts = defs.merge(opts || {})
        var  = opts[:var] if opts[:var]
        value = opts[:upcase] ? ENV[var.to_s.upcase] : ENV[var.to_s]
        # set value nil for an empty env var
        value = nil if value.to_s.empty?
        value || default
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

    # Merged options global with context specific
    def options
      pipe_options.merge(context_pipe_options)
    end

    private

    def pipe_options
      @pipe_options ||= Hashie::Mash.new
    end

    def context_pipe_options
      @context_pipe_options ||= Hash.new(Hashie::Mash.new)
    end
  end
end
