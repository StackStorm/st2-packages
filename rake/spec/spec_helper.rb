require 'hashie'
require 'specinfra'
require 'serverspec'
require 'remote_helpers'
require './rake/pipeline_options'


SSH_OPTIONS = {
  user: 'root',
  keys: ['/root/.ssh/busybee'],
  keys_only: true
}

set :backend, :ssh
set :host, ENV['TESTNODE']
set :ssh_options, SSH_OPTIONS
set :env, LANG: 'en_US.UTF-8', LC_ALL: 'en_US.UTF-8'

# ST2Spec
class ST2Spec
  extend Pipeline::Options
  instance_eval(File.read('rake/build/environment.rb'))

  ST2_SERVICES = %w(st2api st2stream st2auth st2actionrunner st2notifier st2workflowengine
                    st2resultstracker st2rulesengine st2timersengine st2sensorcontainer st2garbagecollector st2scheduler)

  SPECCONF = {
    bin_prefix: '/usr/bin',
    conf_dir: '/etc/st2',
    log_dir: '/var/log/st2',
    package_list: pipeopts.packages,
    rabbitmqhost: pipeopts.rabbitmqhost,
    mongodbhost:  pipeopts.mongodbhost,
    loglines_to_show: 100,
    logdest_pattern: {
      st2actionrunner: 'st2actionrunner.{pid}'
    },
    register_content_command: '/usr/bin/st2-register-content' \
                              ' --register-fail-on-failure' \
                              ' --register-all' \
                              ' --config-dir /etc/st2',

    st2_services: ST2_SERVICES,
    package_opts: {},

    package_has_services: {
      st2: ST2_SERVICES,
    },

    package_has_binaries: {
      st2: %w(st2 st2ctl st2-bootstrap-rmq st2-register-content st2-rule-tester st2-run-pack-tests
              st2-trigger-refire st2 st2-self-check st2-track-result st2-validate-pack-config
              st2-generate-symmetric-crypto-key st2-submit-debug-info),
    },

    package_has_directories: {
      st2: [
        '/etc/st2',
        '/etc/logrotate.d',
        '/opt/stackstorm/packs',
        [ '/var/log/st2', example: Proc.new {|_| be_writable.by('owner')} ]
      ],
    },

    package_has_files: {
      st2: %w(/etc/st2/st2.conf /etc/logrotate.d/st2),
    },

    package_has_users: {
      st2: [
        'st2',
        ['stanley', example: Proc.new {|_| have_home_directory '/home/stanley'} ]
      ],
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
    # Note: We skip /usr/bin/env lines
    interpreter_path = Regexp.last_match[:interpreter]
    if not Regexp.last_match[:interpreter].start_with?("/usr/bin/env")

      describe file(interpreter_path) do
        it { is_expected.to be_file & be_executable }
      end
    end
  end
end
