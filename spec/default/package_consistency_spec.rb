require 'spec_helper'
require 'packages_helper'

packages = PackagesHelper

# Default os package layout. It contains:
#   - A service or multiple service.
#   - Zero or more binaries which.
#
shared_examples 'os package' do |opts|
  context "#{opts[:name]}" do
    describe file("/etc/#{opts[:name]}") do
      it { is_expected.to be_directory }
    end

    # Logging configurations
    if opts[:default_logs]
      describe file("/etc/#{opts[:name]}/logging.conf") do
        it { is_expected.to be_file }
      end

      describe file("/etc/#{opts[:name]}/syslog.conf") do
        it { is_expected.to be_file }
      end
    end

    opts[:logging_conf].each do |log_name|
      describe file("/etc/#{opts[:name]}/logging.#{log_name}.conf") do
        example = described_class
        it { is_expected.to be_file }
        it "should log to #{packages::LOG_DIR}/st2#{log_name}.log" do
          content = example.described_class
          expect(content).to match(%r{#{packages::LOG_DIR}/st2#{log_name}.log})
        end
        it "should log to #{packages::LOG_DIR}/st2#{log_name}.audit.log" do
          content = example.described_class
          expect(content).to \
            match(%r{#{packages::LOG_DIR}/st2#{log_name}.audit.log})
        end
      end

      describe file("/etc/#{opts[:name]}/syslog.#{log_name}.conf") do
        it { is_expected.to be_file }
      end
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
  describe file("#{packages::CONF_DIR}/st2.conf") do
    it { is_expected.to exist }
  end

  packages::COMMON_DIRECTORIES.each do |d|
    describe file(d) do
      it { is_expected.to be_directory }
    end
  end

  describe user(packages::SERVICE_USER) do
    it { is_expected.to exist }
  end

  describe user(packages::STANLEY_USER) do
    it { is_expected.to exist }
    it { is_expected.to have_home_directory "/home/#{packages::STANLEY_USER}" }
  end

  describe file(packages::LOG_DIR) do
    it { is_expected.to be_directory & be_writable.by('owner') }
  end

  describe file("/home/#{packages::STANLEY_USER}") do
    it do
      is_expected.to be_directory & be_writable.by('owner') & \
        be_readable.by('owner') & be_executable.by('owner')
    end
  end
end

describe 'Package consistency' do
  context 'Environment variable' do
    it 'ST2_PACKAGES is non-empty' do
      expect(packages.full_list).not_to be_empty
    end

    it 'PACKAGE_LIST is non-empty' do
      expect(packages.list).not_to be_empty
    end
  end

  packages.list.each do |name|
    describe package(name) do
      it { is_expected.to be_installed }
    end
  end

  include_examples 'st2common'

  it_behaves_like 'os package', packages.opts('st2api')
  it_behaves_like 'os package', packages.opts('st2auth')
  it_behaves_like 'os package', packages.opts('st2actions')
  it_behaves_like 'os package', packages.opts('st2reactor')
end
