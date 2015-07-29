require 'spec_helper'
include ST2Spec::Helper

# OS package shared example group
#
shared_examples 'os package' do |name, opts|
  defs = {
    config_dir: true
  }
  opts = defs.merge(opts || {})

  describe package(name) do
    it { is_expected.to be_installed }
  end

  # check for presence of users
  user_list = (opts[:users] || []) + (spec[:package_has_users][name] || [])
  if user_list
    each_with_options user_list do |u, uopts|
      describe user(u) do
        it { is_expected.to exist }

        # Home directory check
        case uopts[:home]
        when false, nil
        else
          home_dir = uopts[:home] == true ? "/home/#{u}" : "#{uopts[:home]}"
          it { is_expected.to have_home_directory home_dir }
        end
      end
    end
  end

  context 'files' do
    unless opts[:config_dir]
      no_config_dir_msg = 'no services, no configuration directory is needed'
    end

    describe file("/etc/#{name}"), skip: no_config_dir_msg do
      it { is_expected.to be_directory }
    end

    # check for presences of directories
    dir_list = (opts[:directories] || []) + \
               (spec[:package_has_directories][name] || [])
    if dir_list
      each_with_options dir_list do |path, _|
        describe file(path) do
          it { is_expected.to be_directory }
        end
      end
    end

    # check files
    file_list = (opts[:files] || []) + \
                (spec[:package_has_files][name] || [])
    if file_list
      each_with_options file_list do |path, _|
        describe file(path) do
          it { is_expected.to be_file }
        end
      end
    end

    # check binaries
    binary_list = (opts[:binaries] || []) + \
                  (spec[:package_has_binaries][name] || [])
    if binary_list
      each_with_options binary_list do |bin_name, _|
        unless bin_name.start_with? '/'
          prefix = File.join(spec[:bin_prefix], '')
        end
        describe file("#{prefix}#{bin_name}") do
          it_behaves_like 'script or binary'
        end
      end
    end
  end

  context 'services' do
    service_list = (opts[:services] || []) + \
                   (spec[:package_has_services][name] || [])
    if service_list
      each_with_options service_list do |service_name, _|
        prefix = File.join(spec[:bin_prefix], '')
        describe file("#{prefix}#{service_name}") do
          it_behaves_like 'script or binary'
        end

        describe file("/etc/default/#{service_name}"),
                 if: %w(debian ubuntu).include?(os[:family]) do
          it { is_expected.to exist }
        end

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

    it 'PACKAGE_LIST is non-empty' do
      expect(spec[:package_list]).not_to be_empty
    end
  end

  shared_binaries = %w(st2-bootstrap-rmq st2-register-content)

  it_behaves_like 'os package', 'st2common', config_dir: false
  it_behaves_like 'os package', 'st2client', config_dir: false
  it_behaves_like 'os package', 'st2api',  binaries: shared_binaries
  it_behaves_like 'os package', 'st2auth', binaries: shared_binaries
  it_behaves_like 'os package', 'st2actions', binaries: shared_binaries
  it_behaves_like 'os package', 'st2reactor', binaries: shared_binaries

  describe file(spec[:log_dir]) do
    it { is_expected.to be_directory & be_writable.by('owner') }
  end
end
