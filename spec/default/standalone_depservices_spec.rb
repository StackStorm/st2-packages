require 'spec_helper'

shared_examples 'start st2 services' do
  WAITFORSTART = 5

  before(:context) do
    ST2Specs[:services].each do |svc|
      cmd = ST2Specs.backend.command.get(:start_service, svc)
      ST2Specs.backend.run_command(cmd)
    end
    sleep WAITFORSTART
  end
end

describe 'Dependent services' do
  include_examples 'start st2 services'

  # buggy buggy netcat and serverspec!
  describe host(ENV['RABBITMQHOST']) do
    # it { is_expected.to be_reachable }
  end

  describe host(ENV['MONGODBHOST']) do
    # it { is_expected.to be_reachable }
  end

  ST2Specs[:services].each do |svc|
    describe service(svc) do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end
  end
end
