# Depends on SPECS, so the code bellow just makes it work.
#
#

namespace :setup do
  task :all => [:install_artifacts, :configure]

  task :install_artifacts => ['upload:to_testnode', :install_st2_python] do
    pipeline do
      run hostname: opts[:testnode] do |opts|
        with opts.env do
          within opts.artifact_dir do
            execute :bash, "$BASEDIR/scripts/install_os_packages.sh #{opts[:package_list]}"
          end
        end
      end
    end
  end

  task :configure do
    pipeline do
      run hostname: opts[:testnode] do |opts|
        with opts.env do
          if opts.packages.include? 'st2'
            execute :bash, "$BASEDIR/scripts/generate_st2_config.sh"
          end
          if opts.packages.include? 'st2mistral'
            execute :bash, "$BASEDIR/scripts/generate_mistral_config.sh"
          end
        end
      end
    end
  end

  task :install_st2_python do
    # Only run if we use st2_python (currently only used on el6)
    if pipeopts.st2_python == 1
      pipeline do
        run hostname: opts[:testnode] do |opts|
          repo_path = '/etc/yum.repos.d/stackstorm-el6-stable.repo'
          execute :wget, "-nv https://bintray.com/stackstorm/el6/rpm -O #{repo_path}"
          execute :sed, "-ir 's~stackstorm/el6~stackstorm/el6/stable~' #{repo_path}"
          execute :yum, "--nogpgcheck -y install st2python"
        end
      end
    end
  end
end
