require 'serverspec'
require 'specinfra'

set :backend, :ssh
set :host, ENV['TESTHOST']
set :ssh_options, user: 'busybee',
                  keys: ['/root/.ssh/busybee'],
                  keys_only: true

# SpecDefaults module
module SpecDefaults
  CONF_DIR = '/etc/st2'
  LOG_DIR  = '/var/log/st2'
  SERVICE_USER = 'st2'
  STANLEY_USER = 'stanley'
  PACKAGE_LIST = (ENV['PACKAGE_LIST'] || '').split
  ST2_AVAILABLE_PACKAGES = (ENV['ST2_PACKAGES'] || '').split

  OS_PACKAGE_OPTS = {
    'st2actions' => {
      services: %w(st2actionrunner st2notifier st2resultstracker)
    },
    'st2reactor' => {
      services: %w(st2rulesengine st2sensorcontainer),
      binaries: %w(st2-rule-tester st2-trigger-refire)
    }
  }

  COMMON_DIRECTORIES = %W(
    #{CONF_DIR}
    #{LOG_DIR}
    /etc/logrotate.d
    /opt/stackstorm/packs
  )
end

shared_examples 'script or binary' do
  it { is_expected.to be_file & be_executable }

  shebang = /^#!(?<interpreter>.*?)$/m
  if described_class.content.match(shebang)
    describe file(Regexp.last_match[:interpreter]) do
      it { is_expected.to be_file & be_executable }
    end
  end
end
