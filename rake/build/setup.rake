# Depends on SPECS, so the code bellow just makes it work.
#
#

namespace :setup do
  task :all => [:install_artifacts, :configure]

  task :install_artifacts => 'build:upload_to_testnode' do
    pipeline do
      run hostname: opts[:testnode] do |opts|
        packages = opts[:testing_list].join(' ')
        with opts.env do
          within opts.artifact_dir do
            execute :bash, "$BASEDIR/scripts/install_os_packages.sh #{packages}"
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
          if opts.packages.include? :mistral
            execute :bash, "$BASEDIR/scripts/generate_mistral_config.sh"
          end
        end
      end
    end
  end
end
