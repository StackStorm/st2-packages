require 'spec_helper'

# Share example showing remote logs of failed st2 services
#
shared_examples 'show service log on failure' do
  before(:context) { @failed_services = [] }

  after(:each, prompt_on_failure: true) do |example|
    @failed_services << example if example.exception
  end

  after(:all) do
    # Use different ways to grab logs on a remote spec instance.
    def remote_init_type
      probe_cmd = <<-EOS
        (ls -1 /etc/debian_version && dpkg -l upstart) &>/dev/null && echo upstart && exit
        (ls -1 /etc/debian_version) &>/dev/null && echo debian && exit
        (ls -1 /usr/bin/systemctl) &>/dev/null && echo systemd && exit
      EOS
      svtype = spec.backend.run_command(probe_cmd).stdout
      svtype.empty? ? nil : svtype.strip.to_sym
    end

    # Grab remote service stdout logs
    def grab_remote_service_stdout(service_name, lines_num = 20)
      init_type = remote_init_type
      output =  case init_type
                when :upstart
                  path = File.join('/var/log/upstart', service_name)
                  tail_remote_logfile(path, lines_num)
                when :systemd
                  spec.backend.run_command("systemctl status -n #{lines_num} #{service_name}").stdout
                else
                  ''
                end
      if output.empty?
        puts "!!! Couldn't locate #{service_name} #{init_type} service stdout logs"
      else
        output
      end
    end

    # Just tail latest remote log file
    def tail_remote_logfile(path, lines_num = 20)
      cat_cmd = <<-EOS
        file=$(ls -1t #{path}*.log \
          2>/dev/null | sed '1!d')
        [ -z "$file" ] || { cat "$file" | tail -n #{lines_num}; }
      EOS
      spec.backend.run_command(cat_cmd).stdout
    end

    # Grab remote logs, try logfile or try servicestdout logs
    def grab_remote_logs(service_name, lines_num = 20)   
      path = File.join(spec[:log_dir], service_name)  
      output = tail_remote_logfile(path, lines_num)
      if output.empty?
        grab_remote_service_stdout(service_name, lines_num)
      else
        output
      end
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
        output = grab_remote_logs(service.name, lines_num)
        unless output.empty?
          puts "\nlast #{lines_num} lines from log file of service " \
               "#{service.name}"
          puts '>>>', output
        end
      end
    end
  end
end
