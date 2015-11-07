# Depends on SPECS, so the code bellow just makes it work.
#
#

namespace :setup do
  task :all => [:upload_artifacts, :install_artifacts, :configure]

  # We don't need to upload artifacts on docker-compose,
  # since they are passed through in a volume.
  task :upload_artifacts do
    pipeline do
      run hostname: opts[:testnode] do |opts|
        within File.dirname(opts.artifact_dir) do
          rule = [ opts.artifact_dir, File.dirname(opts.artifact_dir) ]
          upload!(*rule, recursive: true)
        end
      end
    end unless pipeopts[:docker_compose].to_i == 1
  end

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
          execute :bash, "$BASEDIR/scripts/config.sh"
          if opts.packages.include? :mistral
            execute :bash, "$BASEDIR/scripts/mistral_setup.sh"
          end
        end
      end
    end
  end
end
