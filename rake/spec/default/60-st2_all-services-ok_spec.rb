require 'spec_helper'
require 'examples/show-service-log-on-failure'

describe 'external services' do
  # Buggy buggy netcat vs serverspec :(
  # Hostnames have to priorly resolved as addresses.

  describe 'rabbitmq' do
    subject { host(spec[:rabbitmqhost]) }
    it { is_expected.to be_reachable }
    it { is_expected.to be_reachable.with :port => 5672, :timeout => 1 }
  end

  describe 'mongodb' do
    subject { host(spec[:mongodbhost]) }
    it { is_expected.to be_reachable }
    it { is_expected.to be_reachable.with :port => 27017, :timeout => 1 }
  end

  if spec[:mistral_enabled]
    describe 'postgres' do
      subject { host(spec[:postgreshost]) }
      it { is_expected.to be_reachable }
      it { is_expected.to be_reachable.with :port => 5432, :timeout => 1 }
    end
  end
end

describe 'start st2 components and services' do
  before(:all) do
    puts "===> Starting st2 services #{spec[:service_list].join(', ')}..."
    remote_start_services(spec[:service_list])

    puts "===> Wait for st2 services to start #{spec[:wait_for_start]} sec..."
    sleep spec[:wait_for_start]

    # Populate mistral db tables with initial data.
    # We don't test this invocation, due to docker-compose up actually DOES NOT
    # start clean postgres (so command fails on the second up invocation %-).
    #
    if spec[:mistral_enabled]
      puts "===> Invoking mistral-db-manage populate..."
      spec.backend.run_command(spec[:mistral_db_populate_command])
    end
    puts
  end

  # Run register content
  describe command(spec[:register_content_command]) do
    after(:all) do
      if described_class.exit_status > 0
        puts "\nRegister content has failed (:", '>>>>>',
             described_class.stderr
      end
    end
    its(:exit_status) { is_expected.to eq 0 }
  end
end

# Check if component services are running
describe 'st2 services' do
  include_examples 'show service log on failure'

  spec[:service_list].each do |name|
    describe service(name), prompt_on_failure: true do
      it { is_expected.to be_running }
      if service(name) == 'st2auth'
        subject { port(9100) }
        it { is_expected.to be_listening }
      elsif service(name) == 'st2api'
        subject { port(9101) }
        it { is_expected.to be_listening }
      elsif service(name) == 'mistral'
        subject { port(8989) }
        it { is_expected.to be_listening }
      end
    end
  end
end
