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
      if opts[:home]
        home_dir = (opts[:home] == true ? "/home/#{u}" : "#{opts[:home]}")
      end

      it { is_expected.to exist }
      it { is_expected.to have_home_directory home_dir if home_dir }
    end
  end

  context 'files' do
    set_context_vars(name, _opts)

    # Check /etc/st2 directory
    #
    describe file(spec[:conf_dir]) do
      it { is_expected.to be_directory }
    end

    # Check for presences of directories
    #
    get_directories do |path, _|
      describe file(path) do
        it { is_expected.to be_directory }
      end
    end

    # Check files
    #
    get_files do |path, _|
      describe file(path) do
        it { is_expected.to be_file }
      end
    end

    # Check binaries
    #
    get_binaries do |bin_name, _|
      unless bin_name.start_with? '/'
        prefix = File.join(spec[:bin_prefix], '')
      end

      describe file("#{prefix}#{bin_name}") do
        it_behaves_like 'script or binary'
      end
    end
  end

  context 'services' do
    set_context_vars(name, _opts)

    # Check services
    #
    get_services do |service_name, _|
      describe file("/usr/share/python/#{venv_name}/bin/#{service_name}") do
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

    it 'BUILDLIST is non-empty' do
      expect(spec[:package_list]).not_to be_empty
    end
  end

  spec[:package_list].each do |pkg_name|
    it_behaves_like 'os package', pkg_name, spec[:package_opts][pkg_name]
  end

  describe file(spec[:log_dir]) do
    it { is_expected.to be_directory & be_writable.by('owner') }
  end
end
