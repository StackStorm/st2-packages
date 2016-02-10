namespace :package do

  ## Create wheels for components and write them to the wheelhouse directory.
  #
  task :prebuild_st2mistral do
    pipeline 'st2mistral' do
      run hostname: opts[:buildnode] do |opts|
        command show_uuid: false
        with opts.env do
          within opts.gitdir do
            make :bdist_wheel, label: 'bdist: st2mistral'
            make :wheelhouse,  label: 'wheelhouse: st2mistral'
          end
        end
      end
    end
  end

  ## Prepare st2 bundle package to be built
  #
  task :post_checkout_st2mistral do
    pipeline 'st2mistral' do
      run hostname: opts[:buildnode] do |opts|
        command show_uuid: false, label: "checkout: update st2mistral"
        with opts.env do
          # Update gitdir with rpmspecs and st2mistral updates.
          within opts.basedir do
            execute :cp, '-r rpmspec/ packages/st2mistral/* $GITDIR'
          end
        end
      end
    end
  end

  ## Build st2mistral bundle package
  #
  task :st2mistral do
    pipeline 'st2mistral' do
      run hostname: opts[:buildnode] do |opts|
        command label: 'package: st2mistral', show_uuid: false
        with opts.env do
          within opts.gitdir do
            make :changelog
            execute :bash, '$BASEDIR/scripts/build_os_package.sh st2mistral'
          end
        end
      end
    end
  end

end
