# Depends on SPECS, so the code bellow just makes it work.
#
#

namespace :setup do
  task :all => [:install_artifacts, :configure]

  task :install_artifacts => ['upload:to_testnode'] do
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
        end
      end
    end
  end
end
