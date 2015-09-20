require 'spec_helper'
require 'examples/show-service-log-on-failure'

describe 'external services' do
  # Buggy buggy netcat vs serverspec!
  describe 'rabbitmq' do
    subject { host(ENV['RABBITMQHOST']) }
    it { is_expected.to be_reachable }
  end

  describe 'mongodb' do
    subject { host(ENV['MONGODBHOST']) }
    it { is_expected.to be_reachable }
  end

  if spec[:mistral_enabled]
    describe 'postgres' do
      subject { host(ENV['POSTGRESHOST']) }
      it { is_expected.to be_reachable }
    end
  end
end

describe 'start st2 components and services' do
  before(:all) do
    puts "===> Starting st2 services #{spec[:service_list].join(', ')}..."
    remote_start_services(spec[:service_list])

    puts "===> Wait for st2 services to start #{spec[:wait_for_start]} sec..."
    sleep spec[:wait_for_start]
  end
  register_content = ::File.join(spec[:bin_prefix],
                                 'st2-register-content --register-all ' \
                                 "--config-dir #{spec[:conf_dir]}")

  describe command(register_content) do
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
    end
  end
end
