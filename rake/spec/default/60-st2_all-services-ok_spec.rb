require 'spec_helper'
require 'examples/show-service-log-on-failure'

describe 'external services' do
  # Buggy buggy netcat vs serverspec :(
  # Hostnames have to priorly resolved as addresses.

  describe 'rabbitmq' do
    subject { host(spec[:rabbitmqhost]) }
    it { is_expected.to be_reachable.with :port => 5672, :timeout => 1 }
  end

  describe 'mongodb' do
    subject { host(spec[:mongodbhost]) }
    it { is_expected.to be_reachable.with :port => 27017, :timeout => 1 }
  end

  if spec[:mistral_enabled]
    describe 'postgres' do
      subject { host(spec[:postgreshost]) }
      it { is_expected.to be_reachable.with :port => 5432, :timeout => 1 }
    end
  end
end

describe 'run mistral DB migration' do
  if spec[:mistral_enabled]
    # Run mistral DB upgrade head
    describe command(spec[:mistral_db_head_command]) do
      its(:exit_status) { is_expected.to eq 0 }
      after(:all) do
        if described_class.exit_status > 0
          puts "\nMistral DB upgrade head has failed (:", '>>>>>',
               described_class.stderr
          puts
        end
      end
    end

    # Run mistral DB populate
    describe command(spec[:mistral_db_populate_command]) do
      its(:exit_status) { is_expected.to eq 0 }
      after(:all) do
        if described_class.exit_status > 0
          puts "Mistral DB populate has failed!", '>>>>>',
               described_class.stderr
          puts
        end
      end
    end
  end
end

describe 'start st2 components and services' do
  before(:all) do
    puts "===> Starting st2 services #{spec[:service_list].join(', ')}..."
    remote_start_services(spec[:service_list])
    puts
  end

  # Run register content
  describe command(spec[:register_content_command]) do
    its(:exit_status) { is_expected.to eq 0 }
    after(:all) do
      if described_class.exit_status > 0
        puts "Register content has failed!", '>>>>>',
             described_class.stderr
        puts
      end
    end
  end
end

# Check if component services are running/enabled
describe 'st2 services' do
  include_examples 'show service log on failure'

  spec[:service_list].each do |name|
    describe service(name), prompt_on_failure: true do
      it { is_expected.to be_running }
      it { should be_enabled }
    end
  end

  describe 'st2auth', prompt_on_failure: true do
    subject { port(9100) }
    it { should be_listening }
  end

  describe 'st2api', prompt_on_failure: true do
    subject { port(9101) }
    it { should be_listening }
  end

  describe 'st2stream', prompt_on_failure: true do
    subject { port(9102) }
    it { should be_listening }
  end

  if spec[:mistral_enabled]
    describe 'mistral', prompt_on_failure: true do
      subject { port(8989) }
      it { should be_listening }
    end
  end
end

# all st2 services should work immediately after restart
describe 'st2 services availability after restart' do
  describe command("st2ctl restart && st2 action list") do
    its(:exit_status) { is_expected.to eq 0 }
  end
end
