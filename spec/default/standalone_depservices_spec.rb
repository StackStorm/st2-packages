require 'spec_helper'

specs = SpecDefaults
#                rabbit     monga
#                  |        /   \
service_ports = [5672, 27_017, 28_017]

case specs.os[:family]
when 'debian', 'ubuntu'
  service_names = %w(mongodb rabbitmq)
  if ENV['MISTRAL_DISABLED'] != '1'
    mysql_service = 'mysql'
    service_ports << 3306
  end
else
  service_names = []
end

describe 'Dependent services' do
  # Check services
  service_names.each do |svc_name|
    describe service(svc_name) do
      it { is_expected.to be_running }
    end
  end

  describe service(mysql_service), if: !mysql_service.nil? do
    it { is_expected.to be_running }
  end

  # Check services listen
  service_ports.each do |pn|
    describe port(pn) do
      it { is_expected.to be_listening }
    end
  end
end
