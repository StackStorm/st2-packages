require 'spec_helper'
require 'remote_logs_helper'

# Bring up all stackstorm services
#
shared_examples 'start st2 services' do
  WAITFORSTART = (ENV['ST2_WAITFORSTART'] || 15).to_i

  before(:context) do
    puts '===> Starting st2 services...'
    spec[:service_list].each do |name|
      cmd = spec.backend.command.get(:start_service, name)
      spec.backend.run_command(cmd)
    end
    puts "===> Wait for st2 services to start #{WAITFORSTART} sec..."
    sleep WAITFORSTART
  end
end

# Main services check up
#
describe 'st2 services check' do
  include_examples 'start st2 services'
  include_examples 'show service log on failure'

  context 'external' do
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
  end

  spec[:service_list].each do |name|
    describe service(name), prompt_on_failure: true do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end
  end
end
