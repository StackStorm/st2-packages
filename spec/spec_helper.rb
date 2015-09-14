require 'hashie'
require 'specinfra'
require 'serverspec'
require 'remote_helpers'

SSH_OPTIONS = {
  user: 'root',
  keys: ['/root/.ssh/busybee'],
  keys_only: true
}

set :backend, :ssh
set :host, ENV['TESTHOST']
set :ssh_options, SSH_OPTIONS

# ST2Spec
class ST2Spec
  ST2_SERVICES = %w(st2api st2auth st2actionrunner st2notifier
                    st2resultstracker st2rulesengine st2sensorcontainer
                    st2exporter)

  SPECCONF = {
    bin_prefix: '/usr/bin',
    conf_dir: '/etc/st2',
    log_dir: '/var/log/st2',
    mistral_enabled: (ENV['MISTRAL_ENABLED'] || 1).to_i == 1,
    package_list: (ENV['TESTLIST'] || '').split,
    available_packages: (ENV['ST2_PACKAGES'] || '').split,
    wait_for_start: (ENV['ST2_WAITFORSTART'] || 15).to_i,
    loglines_to_show: 20,
    logdest_pattern: {
      st2actionrunner: 'st2actionrunner.{pid}'
    },

    st2_services: ST2_SERVICES,
    package_opts: {},

    package_has_services: {
      st2actions: %w(st2actionrunner st2notifier st2resultstracker),
      st2reactor: %w(st2rulesengine st2sensorcontainer),
      st2bundle: %w(st2api st2auth st2actionrunner st2notifier
                     st2resultstracker st2rulesengine st2sensorcontainer st2exporter),
      mistral: [
        ['mistral', binary_name: 'mistral-server']
      ]
    },

    package_has_binaries: {
      st2common: %w(st2-bootstrap-rmq st2-register-content),
      st2reactor: %w(st2-rule-tester st2-trigger-refire),
      st2client: %w(st2),
      st2debug: %w(st2-submit-debug-info),
      st2bundle: %w(st2-bootstrap-rmq st2-register-content st2-rule-tester
                    st2-trigger-refire st2)
    },

    package_has_directories: {
      st2common: [
        '/etc/st2',
        '/etc/logrotate.d',
        '/opt/stackstorm/packs',
        [ '/var/log/st2', example: Proc.new {|_| be_writable.by('owner')} ]
      ],
      st2bundle: %w(/etc/st2 /var/log/st2 /etc/logrotate.d
                    /opt/stackstorm/packs),
      mistral: %w(/etc/mistral)
    },

    package_has_files: {
      st2common: %w(/etc/st2/st2.conf),
      mistral: %w(/etc/mistral/mistral.conf)
    },

    package_has_users: {
      st2common: [
        'st2',
        ['stanley', example: Proc.new {|_| have_home_directory '/home/stanley'} ]
      ],
      mistral: %w(mistral)
    }
  }

  class << self
    ROUTED = [
      :service_list
    ]

    # spec conf reader
    def [](key)
      if ROUTED.include? key.to_sym
        send(key)
      else
        spec[key]
      end
    end

    def service_list
      @services_available ||= begin
        list = ST2_SERVICES
        list << 'mistral' if spec[:mistral_enabled]
        list
      end
    end

    def spec
      @spec ||= Hashie::Mash.new(SPECCONF)
    end

    def backend
      @backend ||= Specinfra::Backend::Ssh.new(
        host: ENV['TESTHOST'],
        ssh_options: ::SSH_OPTIONS
      )
    end
  end

  module Mixin
    def spec
      ST2Spec
    end
  end
end

RSpec.configure do |c|
  [ST2Spec::Mixin, RemoteHelpers].each do |m|
    c.send(:include, m)
    c.send(:extend, m)
  end
end

# Tests binary or script, in later case checks interpreater.
shared_examples 'script or binary' do
  it { is_expected.to be_file & be_executable }

  shebang = /^#!(?<interpreter>.*?)$/m
  if described_class.content.match(shebang)
    describe file(Regexp.last_match[:interpreter]) do
      it { is_expected.to be_file & be_executable }
    end
  end
end
