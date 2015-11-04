#!/usr/bin/env ruby
require './rake/pipeline'
require 'pp'

# We have to run and finalize threaded output dispatcher.
# Otherwise we won't see any output :)
ShellOut.run

task :default => 'packages:build' do
  ShellOut.finalize
end

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

  # target directory for intermidiate files (on the remotes)
  envpass :basedir,  '/root'
  envpass :wheeldir, '/tmp/wheelhouse'

  ssh_options({
    keys: %w(/root/.ssh/busybee),
    auth_methods: %w(publickey)
  })

  upload_onbuild 'packages', 'scripts', 'rpmspec'
end


namespace :packages do
  desc 'Packages build entry task'
  task :build => [:upload, :checkout, :packages]

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
  task :checkout do |this|
    pipeline this.name do
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

  packages_deps = [:build_packages]
  packages_deps.unshift(:st2python) if pipeopts[:st2_python].to_i == 1

  desc 'Build packages, st2python goes first since it is needed during build'
  task :packages => packages_deps

  desc 'Packages build task, each package build is executed parallely'
  multitask :build_packages => [
    :st2common
  ]

  desc 'Build python package (st2python)'
  task :st2python do |this|
    pipeline this.name do
      run hostname: opts[:buildnode] do |opts|
        command label: "package: #{this.short_name}", show_uuid: false

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

  desc 'Build st2common package'
  task :st2common do |this|
    pipeline this.name do
      run hostname: opts[:buildnode] do |opts|
        command label: "package: #{this.short_name}", show_uuid: false

        with opts.env do
          within "#{opts[:st2_gitdir]}/#{this.short_name}" do
            execute :ls, "-l #{opts[:st2_gitdir]}/#{this.short_name}"
            execute :bash, "$BASEDIR/scripts/build_os_package.sh #{this.short_name}"
          end
        end
      end
    end
  end
end
