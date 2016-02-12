require 'hashie'
require 'specinfra'
require 'serverspec'
require 'remote_helpers'
require './rake/pipeline_options'

# Monkey patch to disable systemd operation on debian v8
klass = Class.new(::Specinfra::Command::Debian::Base::Service)
::Specinfra::Command::Debian::V8::Service = klass

SSH_OPTIONS = {
  user: 'root',
  keys: ['/root/.ssh/busybee'],
  keys_only: true
}

set :backend, :ssh
set :host, ENV['TESTNODE']
set :ssh_options, SSH_OPTIONS


# ST2Spec
class ST2Spec
  extend Pipeline::Options
  instance_eval(File.read('rake/build/environment.rb'))

  ST2_SERVICES = %w(st2api st2auth st2actionrunner st2notifier
                    st2resultstracker st2rulesengine st2sensorcontainer st2garbagecollector)

  SPECCONF = {
    bin_prefix: '/usr/bin',
    conf_dir: '/etc/st2',
    log_dir: '/var/log/st2',
    mistral_enabled: Array(pipeopts.packages_to_test).include?('st2mistral'),
    package_list: pipeopts.packages,
    rabbitmqhost: pipeopts.rabbitmqhost,
    postgreshost: pipeopts.postgreshost,
    mongodbhost:  pipeopts.mongodbhost,
    # NB!!! We shouldn't change circle.yml for every branch of `st2`! Hardcode value here so it will work for all tests consistently!
    wait_for_start: ENV['ST2_WAITFORSTART'].to_s != '' ? ENV['ST2_WAITFORSTART'].to_i : 7,
    loglines_to_show: 20,
    logdest_pattern: {
      st2actionrunner: 'st2actionrunner.{pid}'
    },
    register_content_command: '/usr/bin/st2-register-content' \
                              ' --register-fail-on-failure' \
                              ' --register-all' \
                              ' --config-dir /etc/st2',
    mistral_db_head_command: '/opt/stackstorm/mistral/bin/mistral-db-manage' \
                                 ' --config-file /etc/mistral/mistral.conf upgrade head',
    mistral_db_populate_command: '/opt/stackstorm/mistral/bin/mistral-db-manage' \
                                 ' --config-file /etc/mistral/mistral.conf populate',

    st2_services: ST2_SERVICES,
    package_opts: {},

    package_has_services: {
      st2actions: %w(st2actionrunner st2notifier st2resultstracker),
      st2reactor: %w(st2rulesengine st2sensorcontainer st2garbagecollector),
      st2: %w(st2api st2auth st2actionrunner st2notifier
                     st2resultstracker st2rulesengine st2sensorcontainer st2garbagecollector),
      mistral: [
        ['mistral', binary_name: 'mistral-server']
      ]
    },

    package_has_binaries: {
      st2common: %w(st2-bootstrap-rmq st2-register-content st2ctl),
      st2reactor: %w(st2-rule-tester st2-trigger-refire),
      st2client: %w(st2),
      st2debug: %w(st2-submit-debug-info),
      st2: %w(st2-bootstrap-rmq st2-register-content st2-rule-tester
                    st2-trigger-refire st2 st2ctl),
      mistral: %w(mistral)
    },

    package_has_directories: {
      st2common: [
        '/etc/st2',
        '/etc/logrotate.d',
        '/opt/stackstorm/packs',
        [ '/var/log/st2', example: Proc.new {|_| be_writable.by('owner')} ]
      ],
      st2: %w(/etc/st2 /var/log/st2 /etc/logrotate.d
                    /opt/stackstorm/packs),
      mistral: [
        '/etc/mistral',
        [ '/var/log/mistral', example: Proc.new {|_| be_writable.by('owner')} ]
      ]
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
