#!/usr/bin/env ruby
require './rake/pipeline'
require 'pp'

task :default => 'packages:build'

# Set global pipeline options
pipeopts do
  env     :buildnode
  env     :testnodes
  envpass :debug_level, 1
  envpass :compose, 1
  envpass :artifact_dir, '/root/build'    # make it temp??
  envpass :st2_giturl,   'https://github.com/StackStorm/st2'
  envpass :st2_gitrev,   'master'
  envpass :st2_gitdir,    make_tmpname('st2-')
  envpass :st2pkg_version
  envpass :st2pkg_release, 1
  envpass :st2_python, 0
  envpass :st2_python_version, '2.7.10'
  envpass :st2_python_relase, 1

  # Target directory for intermidiate files (on the remotes!)
  envpass :basedir,  '/root'
  envpass :wheeldir, '/tmp/wheelhouse'

  ssh_options({
    keys: %w(/root/.ssh/busybee),
    auth_methods: %w(publickey)
  })

  upload_onbuild 'packages', 'scripts', 'rpmspec'

  st2_packages  :st2common, :st2actions, :st2api, :st2auth, :st2client,
                :st2reactor, :st2exporter, :st2debug
end

# Set max package name length
pipeopts[:name_maxlen] = Array(pipeopts.st2_packages).max {|a, b| a.size <=> b.size}.size


namespace :packages do
  desc 'Packages build entry task'
  task :build => [:upload, :checkout, :packages] do
    pipeline do
      run hostname: opts[:buildnode] do |opts|
        with opts.env do
          execute :ls, '-l $ARTIFACT_DIR', verbosity: :debug
        end
      end
    end
  end

  synthetic_deps = pipeopts[:upload_onbuild].map {|s| "_uponbuild_#{s}"}

  desc 'Parallely upload given sources onto the remotes'
  multitask :upload => synthetic_deps

  rule %r/_uponbuild_/ do |task|
    pipeline do
      run hostname: opts[:buildnode] do |opts|
        source = task.short_name.sub(/_uponbuild_/, '')
        upload! source, opts[:basedir], recursive: true
      end
    end
  end

  desc "Checkout st2 source from github.com"
  task :checkout do |task|
    pipeline task.name do
      run hostname: opts[:buildnode] do |opts|
        command label: 'checkout: st2', show_uuid: false

        with opts.env do
          execute :mkdir, '-p $ARTIFACT_DIR'

          within opts.basedir do
            execute :git, :clone, '--depth 1 -b $ST2_GITREV $ST2_GITURL $ST2_GITDIR'
            execute :cp,  "-r rpmspec/ packages/st2* $ST2_GITDIR"
          end
        end
      end
    end
  end

  desc 'Build python package (st2python)'
  task :st2python do |task|
    pipeline task.name do
      run hostname: opts[:buildnode] do |opts|
        command label: "package: #{task.short_name}", show_uuid: false

        with opts.env do
          within "#{opts[:basedir]}/packages/python" do
            execute :bash, "$BASEDIR/scripts/build_python.sh"
          end

          within "#{opts[:artifact_dir]}" do
            execute :bash, "$BASEDIR/scripts/install_os_package.sh st2python"
          end
        end
      end
    end
  end

  # pip showed dead locks on parallel execution
  desc 'Wheelhouse pre-population'
  task :wheelhouse do
    pipeline do
      run hostname: opts[:buildnode] do |opts|
        command show_uuid: false

        with opts.env do
          # Populate wheelhouse
          Array(opts.st2_packages).each do |package_name|
            within "#{opts[:st2_gitdir]}/#{package_name}" do
              make :wheelhouse, label: "wheelhouse: %#{opts[:name_maxlen]}s" % package_name
            end
          end

          # Create st2common wheel into the wheelhouse
          within "#{opts[:st2_gitdir]}/st2common" do
            make :requirements, label: "wheelhouse: %#{opts[:name_maxlen]}s" % ['st2common']
            make :bdist_wheel, label: "wheelhouse: %#{opts[:name_maxlen]}s" % ['st2common']
          end
        end
      end
    end
  end

  packages_deps = [:wheelhouse, :build_packages]
  packages_deps.unshift(:st2python) if pipeopts[:st2_python].to_i == 1

  desc 'Build packages, st2python goes first since it is needed during build'
  task :packages => packages_deps

  desc 'Packages build task, each package build is executed parallely'
  multitask :build_packages => pipeopts.st2_packages


  desc 'St2 package build task generation rule (st2 packages use the same scenario)'
  rule %r/st2*/ do |task|
    pipeline task.name do
      run hostname: opts[:buildnode] do |opts|
        command label: "package: %#{opts[:name_maxlen]}s" % task.short_name, show_uuid: false

        with opts.env do
          within "#{opts[:st2_gitdir]}/#{task.short_name}" do
            make :changelog
            execute :bash, "$BASEDIR/scripts/build_os_package.sh #{task.short_name}"
          end
        end
      end
    end
  end
end
