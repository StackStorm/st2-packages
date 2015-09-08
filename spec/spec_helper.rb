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
  SPECCONF = {
    bin_prefix: '/usr/bin',
    conf_dir: '/etc/st2',
    log_dir: '/var/log/st2',
    package_list: (ENV['BUILDLIST'] || '').split,
    available_packages: (ENV['ST2_PACKAGES'] || '').split,
    mistral_disabled: ENV['MISTRAL_DISABLED'] || false,
    wait_for_start: (ENV['ST2_WAITFORSTART'] || 15).to_i,

    service_list: %w(st2api st2auth st2actionrunner st2notifier
                     st2resultstracker st2rulesengine st2sensorcontainer st2exporter),

    loglines_to_show: 20,
    logdest_pattern: {
      st2actionrunner: 'st2actionrunner.{pid}'
    },

    package_opts: {},

    package_has_services: {
      st2actions: %w(st2actionrunner st2notifier st2resultstracker),
      st2reactor: %w(st2rulesengine st2sensorcontainer),
      st2bundle: %w(st2api st2auth st2actionrunner st2notifier
                     st2resultstracker st2rulesengine st2sensorcontainer st2exporter)
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
      st2common: %w(/etc/st2 /var/log/st2 /etc/logrotate.d
                    /opt/stackstorm/packs),
      st2bundle: %w(/etc/st2 /var/log/st2 /etc/logrotate.d
                    /opt/stackstorm/packs)
    },

    package_has_files: {
      st2common: %w(/etc/st2/st2.conf)
    },

    package_has_users: {
      st2common: [
        'st2',
        ['stanley', home: true]
      ]
    }
  }

  class << self
    # spec conf reader
    def [](key)
      spec[key]
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
