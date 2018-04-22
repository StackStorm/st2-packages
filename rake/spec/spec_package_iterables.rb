module SpecPackageIterables
  attr_reader :name, :venv_name, :opts

  def set_context_vars(name, opts)
    @name = name
    @opts = Hashie::Mash.new.merge(opts || {})
    # we use different venv name for st2 package (bundle)
    @venv_name = (name.to_s == 'st2' ? 'st2' : name).to_s
    @venv_name = (name.to_s == 'st2mistral' ? 'mistral' : name).to_s
  end

  # Collection iterating methods over spec lists
  # opts[:files] + spec[:package_has_files], etc.
  %w(
    users
    files
    directories
    binaries
    services
  ).each do |collection|
    class_eval <<-"end_eval", __FILE__, __LINE__
      def get_#{collection}(&block)
        list = Array(self.opts[:#{collection}]) +
               Array(self.spec[:package_has_#{collection}][name])
        list.each do |v|
          # Invoke w/wo opts. For example if pair is given ['stanley', {'home'=>true}]
          # it's passed as is if just a value such as 'st2' it'll be passed as ['st2', {}].
          v.is_a?(Array) ? block.call(v) : block.call([v, {}])
        end
      end
    end_eval
  end
end
