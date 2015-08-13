require 'hashie'
require 'specinfra'

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
    etc_dir: '/etc',
    conf_dir: '/etc/st2',
    log_dir: '/var/log/st2',
    package_list: (ENV['BUILDLIST'] || '').split,
    available_packages: (ENV['ST2_PACKAGES'] || '').split,
    mistral_disabled: ENV['MISTRAL_DISABLED'] || false,

    service_list: %w(st2api st2auth st2actionrunner st2notifier
                     st2resultstracker st2rulesengine st2sensorcontainer),

    separate_log_config: %w(st2notifier st2resultstracker
                            st2rulesengine st2sensorcontainer),

    loglines_to_show: 20,
    logdest_pattern: {
      st2actionrunner: 'st2actionrunner.{pid}'
    },

    package_has_services: {
      st2actions: %w(st2actionrunner st2notifier st2resultstracker),
      st2reactor: %w(st2rulesengine st2sensorcontainer)
    },

    package_has_binaries: {
      st2reactor: %w(st2-rule-tester st2-trigger-refire)
    },

    package_has_directories: {
      st2common: %w(/etc/st2 /var/log/st2 /etc/logrotate.d
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

  # Helper mixin
  module Helper
    def spec
      ST2Spec
    end

    def each_with_options(collection, &block)
      (collection || []).each do |i|
        i.is_a?(Array) ? block.call(i) : block.call([i, {}])
      end
    end
  end
end
