require 'spec_helper'

# Share example showing remote logs of failed to start services
#
shared_examples 'show service log on failure' do
  before(:all) { @failed_services = [] }

  after(:each, prompt_on_failure: true) do |example|
    @failed_services << example if example.exception
  end

  after(:all) do
    unless @failed_services.empty?
      puts '===> Showing output from log files of the failed services'
      @failed_services.each do |example|
        service = example.metadata[:described_class]
        lines_num = spec[:loglines_to_show]

        unless service.is_a? Serverspec::Type::Service
          fail 'Serverspec service is required to be described class!'
        end

        output = remote_grab_service_logs(service.name, lines_num)
        unless output.empty?
          puts "\nlast #{lines_num} lines from log file of service " \
               "#{service.name}"
          puts '>>>', output
        end
      end
    end
  end
end
