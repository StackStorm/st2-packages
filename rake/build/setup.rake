# Depends on SPECS, so the code bellow just makes it work.
#
#

namespace :setup do
  all_deps = [:install_artifacts, :configure]
  all_deps.unshift(:install_st2_python) if pipeopts.st2python_enabled

  task :all => all_deps

  task :install_artifacts => 'build:upload_to_testnode' do
    pipeline do
      run hostname: opts[:testnode] do |opts|
        package_list = opts.packages_to_test.join(' ')
        with opts.env do
          within opts.artifact_dir do
            execute :bash, "$BASEDIR/scripts/install_os_packages.sh #{package_list}"
          end
        end
      end
    end
  end

  task :configure do
    pipeline do
      run hostname: opts[:testnode] do |opts|
        with opts.env do
          execute :bash, "$BASEDIR/scripts/generate_st2_config.sh"
          if opts.packages_to_test.include? 'mistral'
            execute :bash, "$BASEDIR/scripts/generate_mistral_config.sh"
          end
        end
      end
    end
  end

  task :install_st2_python do
    pipeline do
      run hostname: opts[:testnode] do |opts|
        repo_path = '/etc/yum.repos.d/stackstorm-el6-stable.repo'
        execute :wget, "https://bintray.com/stackstorm/el6/rpm -O #{repo_path}"
        execute :sed, "-ir 's~stackstorm/el6~stackstorm/el6/stable~' #{repo_path}"
        execute :yum, "-y install st2python"
      end
    end
  end
end
