require 'spec_helper'

module OSPkgHelpers
  attr_reader :name, :venv_name, :opts

  def set_context_vars(name, opts)
    @name = name
    @opts = Hashie::Mash.new.merge(opts || {})
    # we use different venv name for st2bundle package
    @venv_name = (name == 'st2bundle' ? 'st2' : name)
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

# OS package shared example group
#
shared_examples 'os package' do |name, _opts|
  extend OSPkgHelpers
  set_context_vars(name, _opts)

  describe package(name) do
    it { is_expected.to be_installed }
  end

  # Check for presence of users
  #
  get_users do |u, opts|
    describe user(u) do
      it { is_expected.to exist }
      it { is_expected.to instance_eval(&opts[:example])} if opts[:example]
    end
  end

  context 'files' do
    set_context_vars(name, _opts)

    # Check for presences of directories
    #
    get_directories do |path, opts|
      describe file(path) do
        it { is_expected.to be_directory }
        it { is_expected.to instance_eval(&opts[:example])} if opts[:example]
      end
    end

    # Check files
    #
    get_files do |path, opts|
      describe file(path) do
        it { is_expected.to be_file }
        it { is_expected.to instance_eval(&opts[:example])} if opts[:example]
      end
    end

    # Check binaries
    #
    get_binaries do |bin_name, opts|
      unless bin_name.start_with? '/'
        prefix = File.join(spec[:bin_prefix], '')
      end

      describe file("#{prefix}#{bin_name}") do
        it_behaves_like 'script or binary'
        it { is_expected.to instance_eval(&opts[:example])} if opts[:example]
      end
    end
  end

  context 'services' do
    set_context_vars(name, _opts)

    # Check services
    #
    get_services do |service_name, opts|
      binary_name = opts[:binary_name] || service_name
      describe file("/usr/share/python/#{venv_name}/bin/#{binary_name}") do
        it_behaves_like 'script or binary'
      end

      if name != 'st2bundle'
        describe service(service_name) do
          it { is_expected.to be_enabled }
        end
      end
    end
  end
end

# Main example group checking package consistency
#
describe 'packages consistency' do
  context 'environment variable' do
    it 'ST2_PACKAGES is non-empty' do
      expect(spec[:available_packages]).not_to be_empty
    end

    it 'TESTLIST is non-empty' do
      expect(spec[:package_list]).not_to be_empty
    end
  end

  spec[:package_list].each do |pkg_name|
    it_behaves_like 'os package', pkg_name, spec[:package_opts][pkg_name]
  end
end
