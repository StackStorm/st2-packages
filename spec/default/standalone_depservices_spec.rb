require 'spec_helper'

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

# Cat contents of service log files in case of failure.
#
shared_examples 'show service log on failure' do
  before(:context) { @failed_services = [] }

  after(:each, prompt_on_failure: true) do |example|
    @failed_services << example if example.exception
  end

  after(:all) do
    # runs tail on remote through serverspec backend
    def tail_remote_logfile(path, lines_num = 20)
      cat_cmd = <<-EOS
        file=$(ls -1t #{path}*.log \
          2>/dev/null | sed '1!d')
        [ -z "$file" ] || { cat "$file" | tail -n #{lines_num}; }
      EOS
      spec.backend.run_command(cat_cmd).stdout
    end

    # Try to fetch stdout, this works for,
    # though it can be extended later.
    def try_stdout_of_remote_service(service_name, lines_num = 20)
      path = File.join('/var/log/upstart', service_name)
      tail_remote_logfile(path, lines_num)
    end

    unless @failed_services.empty?
      puts '===> Showing output from log files of the failed services'
      @failed_services.each do |example|
        service = example.metadata[:described_class]
        lines_num = spec[:loglines_to_show]

        unless service.is_a? Serverspec::Type::Service
          fail 'Serverspec service is required to be described class!'
        end

        # try to tail service logfile
        path = File.join(spec[:log_dir], service.name)
        output = tail_remote_logfile(path, lines_num)
        unless output.empty?
          puts "\nlast #{lines_num} lines from log file of service " \
               "#{service.name}"
          puts '>>>', output
          next
        end

        # if it's missing try to locate its stdout
        stdout = try_stdout_of_remote_service(service.name, lines_num)
        if stdout.empty?
          puts "log file is missing for service #{service.name}!"
        else
          puts "\nlast #{lines_num} lines from stdout of service " \
               "#{service.name}"
          puts '>>>', stdout
        end
      end
    end
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
