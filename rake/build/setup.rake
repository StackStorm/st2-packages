# Depends on SPECS, so the code bellow just makes it work.
#
#

namespace :setup do
  task :all => [:install_artifacts, :configure]
  packages_to_install = pipeopts.packages_to_test
  packages_to_install.unshift('st2python') if pipeopts.st2python_enabled

  task :install_artifacts => 'build:upload_to_testnode' do
    pipeline do
      run hostname: opts[:testnode] do |opts|
        package_list = packages_to_install.join(' ')
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
          if packages_to_install.include? 'mistral'
            execute :bash, "$BASEDIR/scripts/generate_mistral_config.sh"
          end
        end
      end
    end
  end
end
