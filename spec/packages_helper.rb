# PackagesHelper
#
module PackagesHelper
  CONF_DIR = '/etc/st2'
  LOG_DIR  = '/var/log/st2'

  OS_PACKAGE_OPTS = {
    'st2actions' => {
      services: %w(st2actionrunner st2notifier st2resultstracker),
      logging_conf: %w(notifier resultstracker)
    },
    'st2reactor' => {
      services: %w(st2rulesengine st2sensorcontainer),
      binaries: %w(st2-rule-tester st2-trigger-refire),
      logging_conf: %w(rulesengine sensorcontainer),
      default_logs: false
    }
  }

  COMMON_DIRECTORIES = %W(
    #{CONF_DIR}
    #{LOG_DIR}
    /etc/logrotate.d
    /opt/stackstorm/packs
  )

  SERVICE_USER = 'st2'
  STANLEY_USER = 'stanley'

  class << self
    # Full list of available st2 packages
    def full_list
      @full_list ||= (ENV['ST2_PACKAGES'] || '').split
    end

    # Package list to be tested
    def list
      @list ||= (ENV['PACKAGE_LIST'] || '').split
    end

    # OS package options hash generating method
    def opts(package_name)
      {
        name: package_name,
        services: [package_name],
        binaries: [],
        logging_conf: [],
        default_logs: true
      }.merge(OS_PACKAGE_OPTS[package_name] || {})
    end
  end
end
