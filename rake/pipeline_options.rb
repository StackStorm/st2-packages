require 'tempfile'

module Pipeline
  module Options

    # This class implements merged mash context.
    #   Level 1 (named) context merged with level 0 (global).
    #
    class MergedContext
      def initialize
        @global ||= Hashie::Mash.new
        @named_context ||= Hash.new {|h, k| h[k] =  Hashie::Mash.new}
      end

      # Lookup value in the MergedContext.
      # First try to fetch value from level 1 named context, then fallback
      # to level 0.
      def lookup_value(key, context=nil)
        [named_context[context] || {}, global].map {|c| c[key]}.compact.first
      end

      # Get global or named context
      def fetch(context=nil)
        context.nil? ? global : named_context[context]
      end

      private
      attr_reader :global, :named_context
    end

    # DSL to build up merged context from environment variables.
    class EnvironmentDSL
      def initialize(context_name, merged_context)
        @context_name = context_name
        @context = merged_context
        @current = merged_context.fetch(context_name)
      end

      # Sets option from env
      def env(attribute, default=nil, opts={})
        _, value, opts = parse_attribute(attribute, default, opts)
        convert_value(value, opts).tap do |v|
          current.assign_property(attribute, v) if v
        end
      end

      # Sets option from env as well as corresponding options env[attribute]
      def envpass(attribute, default=nil, opts={})
        varname, value, opts = parse_attribute(attribute, default, opts)
        convert_value(value, opts).tap do |v|
          if v
            current.assign_property(attribute, v)
            current[:env] ||= Hashie::Mash.new
            current[:env].merge!({varname => v.to_s})
          end
        end
      end

      def pipeopts(context_name=nil)
        context.fetch(context_name)
      end

      def make_tmpname(basename='', tmpdir=Dir.tmpdir)
        Dir::Tmpname.make_tmpname File.join(tmpdir, basename), nil
      end

      def method_missing(method_name, *args)
        if args.size == 0
          # act as getter ONLY IF variable was already assigned
          value = context.lookup_value(method_name, context_name)
          return value unless value.nil?
        end
        # Otherwise we act as setter (even if args.size == 0)
        value = args.size < 2 ? args.pop : args
        current.assign_property(method_name, value)
        value
      end

      private
      attr_reader :context_name, :context, :current


      # Parse attribute read configuration, to build up [varname, value, opts].
      # During parsing we fetch values from ENV.
      def parse_attribute(attribute, default, opts)
        opts, default = default, nil if default.is_a?(Hash)
        # Merge-in default opts!
        opts = {upcase: true}.merge!(opts)
        caseattr = opts[:upcase] == true ? attribute.to_s.upcase : attribute.to_s
        value = ENV[opts[:from] || caseattr]
        if opts[:reset]
          # don't parse env variable, just set value
          [caseattr, default, opts]
        elsif value == ""
          # use default, when passed env is empty
          [caseattr, default, opts]
        else
          [caseattr, value || default, opts]
        end
      end

      # Convert value if proc option is provided.
      def convert_value(value, opts)
        if opts[:proc].is_a? Proc
          opts[:proc].(value)
        else
          value
        end
      end
    end

    # Store options into mash either global or context specific.
    def pipeopts(context_name=nil, &block)
      unless block.nil?
        # evaluate pipopts DSL
        EnvironmentDSL.new(context_name, context).instance_exec(&block)
      else
        # return current context
        context.fetch(context_name)
      end
    end

    private

    def context
      @context ||= MergedContext.new
    end

  end
end
