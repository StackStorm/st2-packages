require 'spec_helper'
require 'packages_helper'

packages = PackagesHelper
contexts_available = %w(st2actions st2api st2auth st2common st2reactor)

shared_examples 'common binaries' do
  describe file('/usr/bin/st2-bootstrap-rmq') do
    it_behaves_like 'script or binary'
  end

  describe file('/usr/bin/st2-register-content') do
    it_behaves_like 'script or binary'
  end
end

# Package st2actions check up
shared_context 'st2actions' do
  services = %w(st2actionrunner st2notifier st2resultstracker)
  services.each do |service_name|
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

  include_examples 'common binaries'
end

# Package st2api check up
shared_context 'st2api' do
  describe file('/usr/bin/st2api') do
    it_behaves_like 'script or binary'
  end

  describe file('/etc/default/st2api'),
           if: %w(debian ubuntu).include?(os[:family]) do
    it { is_expected.to exist }
  end

  describe service('st2api') do
    it { is_expected.to be_enabled }
  end

  include_examples 'common binaries'
end

# Package st2auth check up
shared_context 'st2auth' do
  describe file('/usr/bin/st2auth') do
    it_behaves_like 'script or binary'
  end

  describe file('/etc/default/st2auth'),
           if: %w(debian ubuntu).include?(os[:family]) do
    it { is_expected.to exist }
  end

  describe service('st2auth') do
    it { is_expected.to be_enabled }
  end

  include_examples 'common binaries'
end

# Package st2common check up
shared_context 'st2common' do
  describe file('/etc/st2/st2.conf') do
    it { is_expected.to exist }
  end

  packages.essential_directories.each do |d|
    describe file(d) do
      it { is_expected.to be_directory }
    end
  end

  describe user(packages.service_user) do
    it { is_expected.to exist }
  end

  describe user(packages.stanley_user) do
    it { is_expected.to exist }
    it { is_expected.to have_home_directory '/home/stanley' }
  end

  describe file('/var/log/st2') do
    it { is_expected.to be_directory & be_writable.by('owner') }
  end

  describe file('/home/stanley') do
    it do
      is_expected.to be_directory & be_writable.by('owner') & \
        be_readable.by('owner') & be_executable.by('owner')
    end
  end
end

# Package st2reactor check up
shared_context 'st2reactor' do
  services = %w(st2rulesengine st2sensorcontainer)
  services.each do |service_name|
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

  binaries = %w(st2-rule-tester st2-trigger-refire)
  binaries.each do |binary|
    describe file("/usr/bin/#{binary}") do
      it_behaves_like 'script or binary'
    end
  end

  include_examples 'common binaries'
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
    # package should be installed
    describe package(name) do
      it { is_expected.to be_installed }
    end

    include_context(name) if contexts_available.include?(name)
  end
end
