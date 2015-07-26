require 'spec_helper'

# Default os package layout. It contains:
#   - A service or multiple service.
#   - Zero or more binaries which.
#
shared_examples 'os package' do |package_name|
  opts = ST2Specs.package_opts[package_name]

  context "#{opts[:name]}" do
    describe file("/etc/#{opts[:name]}") do
      it { is_expected.to be_directory }
    end

    # Check services files
    opts[:services].each do |service_name|
      describe file("/usr/bin/#{service_name}") do
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

    # Check binaries
    opts[:binaries].each do |binary|
      describe file("/usr/bin/#{binary}") do
        it_behaves_like 'script or binary'
      end
    end

    # Shared binares are installed by multiple st2 packages.
    # They exist due to st2common and require it, however st2common
    # is not packaged with its own  virtualenv.
    #
    describe file('/usr/bin/st2-bootstrap-rmq') do
      it_behaves_like 'script or binary'
    end

    describe file('/usr/bin/st2-register-content') do
      it_behaves_like 'script or binary'
    end
  end
end

# Package st2common examples
shared_context 'st2common' do
  describe file("#{ST2Specs[:conf_dir]}/st2.conf") do
    it { is_expected.to exist }
  end

  ST2Specs[:common_dirs].each do |d|
    describe file(d) do
      it { is_expected.to be_directory }
    end
  end

  describe user(ST2Specs[:service_user]) do
    it { is_expected.to exist }
  end

  describe user(ST2Specs[:stanley_user]) do
    it { is_expected.to exist }
    it { is_expected.to have_home_directory "/home/#{ST2Specs[:stanley_user]}" }
  end

  describe file(ST2Specs[:log_dir]) do
    it { is_expected.to be_directory & be_writable.by('owner') }
  end

  describe file("/home/#{ST2Specs[:stanley_user]}") do
    it do
      is_expected.to be_directory & be_writable.by('owner') & \
        be_readable.by('owner') & be_executable.by('owner')
    end
  end
end

describe 'Package consistency' do
  context 'Environment variable' do
    it 'ST2_PACKAGES is non-empty' do
      expect(ST2Specs[:available_packages]).not_to be_empty
    end

    it 'PACKAGE_LIST is non-empty' do
      expect(ST2Specs[:package_list]).not_to be_empty
    end
  end

  ST2Specs[:package_list].each do |name|
    describe package(name) do
      it { is_expected.to be_installed }
    end
  end

  include_examples 'st2common'

  it_behaves_like 'os package', 'st2api'
  it_behaves_like 'os package', 'st2auth'
  it_behaves_like 'os package', 'st2actions'
  it_behaves_like 'os package', 'st2reactor'
end
