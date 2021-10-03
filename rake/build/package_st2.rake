namespace :package do

  ## Create wheels for components and write them to the wheelhouse directory.
  #
  task :prebuild_st2 do
    pipeline 'st2' do
      run hostname: opts[:buildnode] do |opts|
        command show_uuid: false
        with opts.env do
          opts.components.each do |component|
            within ::File.join(opts.gitdir, component) do
              make :info, label: "make info"
              make :bdist_wheel, label: "bdist: #{component}"
            end
          end
          within ::File.join(opts.gitdir, 'st2') do
            make :wheelhouse, label: 'wheelhouse: st2'
          end
        end
      end
    end
  end

  ## Prepare st2 bundle package to be built
  #
  task :post_checkout_st2 do
    pipeline 'st2' do
      run hostname: opts[:buildnode] do |opts|
        command show_uuid: false, label: "checkout: update st2"
        with opts.env do
          # Update gitdir with rpmspecs and st2 packagedir
          within opts.basedir do
            execute :cp, '-r rpmspec/ packages/st2/ $GITDIR'
            opts.components.each do |component|
              execute :cp, "packages/st2/component.makefile ${GITDIR}/#{component}/Makefile"
            end
            # hack! Drop once fixed in st2.git
            execute :sed, '-i -e "s/python /python3 /" -e "s/print __version__/print(__version__)/" $GITDIR/scripts/populate-package-meta.sh'
            execute :bash, '$GITDIR/scripts/populate-package-meta.sh'
          end
        end
      end
    end
  end

  ## Build st2 bundle package
  #
  task :st2 do
    pipeline 'st2' do
      run hostname: opts[:buildnode] do |opts|
        command label: 'package: st2', show_uuid: false
        with opts.env do
          within ::File.join(opts.gitdir, 'st2') do
            make :changelog
            execute :bash, '$BASEDIR/scripts/build_os_package.sh st2'
          end
        end
      end
    end
  end

end
