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

# ST2Specs helper class
class ST2Specs
  SPECCONF = {
    conf_dir: '/etc/st2',
    log_dir: '/var/log/st2',
    service_user: 'st2',
    stanley_user: 'stanley',
    package_list: (ENV['PACKAGE_LIST'] || '').split,
    available_packages: (ENV['ST2_PACKAGES'] || '').split,
    mistral_disabled: ENV['MISTRAL_DISABLED'] || false,
    common_dirs: %w(
      /etc/st2
      /var/log/st2
      /etc/logrotate.d
      /opt/stackstorm/packs
    )
  }

  PACKAGE_OPTS = {
    st2actions: {
      services: %w(st2actionrunner st2notifier st2resultstracker)
    },
    st2reactor: {
      services: %w(st2rulesengine st2sensorcontainer),
      binaries: %w(st2-rule-tester st2-trigger-refire)
    }
  }

  SERVICES = %w(
    st2api
    st2auth
  ) + PACKAGE_OPTS.map { |_, opts| opts[:services] }.flatten

  class << self
    # spec conf reader
    def [](key)
      conf[key]
    end

    def conf
      @spec ||= begin
        mash = Hashie::Mash.new(SPECCONF)
        mash.merge(services: SERVICES)
      end
    end

    def package_opts
      @package_opts ||= begin
        mash = Hashie::Mash.new(PACKAGE_OPTS)
        _set_package_defaults(_fetch_override(mash))
      end
    end

    def backend
      @backend ||= Specinfra::Backend::Ssh.new(
        host: ENV['TESTHOST'],
        ssh_options: ::SSH_OPTIONS
      )
    end

    private

    # Meta sugar for PACKAGE_OPTS
    def _fetch_override(o)
      class << o; self; end.class_eval %{
        def [](key)
          current = fetch(key, nil)
          defaults = self._package_defaults(key)
          current.nil? ? defaults : defaults.merge(current)
        end
      }
      o
    end

    def _set_package_defaults(o)
      class << o; self; end.class_eval %@
        def _package_defaults(key)
          Hashie::Mash.new({name: key.to_s, services: [key.to_s], binaries: []})
        end
      @
      o
    end
  end
end
