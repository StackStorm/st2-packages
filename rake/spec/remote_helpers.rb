module RemoteHelpers
  # Module provides helpers for various remote operations.

  # start service or a list of services
  def remote_start_services(sv_or_list)
    Array(sv_or_list).each do |sv|
      sv_start_cmd = spec.backend.command.get(:start_service, sv)
      spec.backend.run_command(sv_start_cmd)
    end
  end

  # Use different ways to grab logs on a remote spec instance.
  def remote_init_type
    probe_cmd = <<-EOS
      ls -1 /etc/debian_version 1>/dev/null 2>&1 && dpkg -l upstart 1>/dev/null 2>&1 && echo upstart && exit
      ls -1 /etc/debian_version 1>/dev/null 2>&1 && echo debian && exit
      ls -1 /usr/bin/systemctl 1>/dev/null 2>&1 && echo systemd && exit
    EOS
    svtype = spec.backend.run_command(probe_cmd).stdout
    svtype.empty? ? nil : svtype.strip.to_sym
  end

  # Grab remote service stdout logs
  def remote_grab_service_stdout(service_name, lines_num = 30)
    init_type = remote_init_type
    output =  case init_type
              when :systemd
                spec.backend.run_command("journalctl -n #{lines_num} -u #{service_name}").stdout
              else
                ''
              end
    if output.empty?
      "!!! Couldn't locate #{service_name} #{init_type} service stdout logs"
    else
      output
    end
  end

  # Just tail latest remote log file
  def remote_tail_logfile(path, lines_num = 20)
    cat_cmd = <<-EOS
      file=$(ls -1t #{path}*.log \
        2>/dev/null | sed '1!d')
      [ -z "$file" ] || { cat "$file" | tail -n #{lines_num}; }
    EOS
    spec.backend.run_command(cat_cmd).stdout
  end

  # Grab remote logs, try logfile or try servicestdout logs
  def remote_grab_service_logs(service_name, lines_num = 20)   
    path = File.join(spec[:log_dir], service_name)  
    output = remote_tail_logfile(path, lines_num)
    if output.empty?
      remote_grab_service_stdout(service_name, lines_num)
    else
      output
    end
  end
end
