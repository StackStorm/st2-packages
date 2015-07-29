require 'spec_helper'

shared_examples 'start st2 services' do
  WAITFORSTART = (ENV['ST2_WAITFORSTART'] || 2).to_i

  before(:context) do
    spec[:service_list].each do |svc|
      cmd = spec.backend.command.get(:start_service, svc)
      spec.backend.run_command(cmd)
    end
    puts "===> Wait for st2 services to start #{WAITFORSTART} sec..."
    sleep WAITFORSTART
  end
end

describe 'St2 services and dependencies' do
  include_examples 'start st2 services'
  # include_examples 'service show logs on failure'

  # buggy buggy netcat and serverspec!
  describe host(ENV['RABBITMQHOST']) do
    it { is_expected.to be_reachable }
    # the next is buggy :(, thus disabled
    # it { is_expected.to be_reachable.with(port: 5672) }
  end

  describe host(ENV['MONGODBHOST']) do
    it { is_expected.to be_reachable }
    # it { is_expected.to be_reachable.with(port: 27_017) }
  end

  spec[:service_list].each do |svc|
    describe service(svc), show_logs_on_failure: true do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end
  end
end
