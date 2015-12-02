require 'spec_helper'
require 'spec_package_iterables'

# OS package shared example group
#
shared_examples 'os package' do |name, _opts|
  extend SpecPackageIterables
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
    end
  end
end

# Main example group checking package consistency
#
describe 'packages consistency' do
  spec[:package_list].each do |pkg_name|
    it_behaves_like 'os package', pkg_name, spec[:package_opts][pkg_name]
  end
end
