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
  basedir '/root'

  ssh_options({
    keys: %w(/root/.ssh/busybee),
    auth_methods: %w(publickey)
  })

  upload_onbuild 'packages', 'scripts'
end


namespace :packages do
  desc 'Packages build entry task'
  task :build => [:upload, :build_packages]

  syntheticdeps = pipeopts[:upload_onbuild].map {|s| "_uponbuild_#{s}"}

  desc 'Parallely upload given sources onto the remotes'
  multitask :upload => syntheticdeps

  rule %r/_uponbuild_/ do |task|
    pipeline do
      run hostname: opts[:buildnode] do |opts|
        source = task.short_name.sub(/_uponbuild_/, '')
        upload! source, opts[:basedir], recursive: true
      end
    end
  end

  desc 'Packages build task, each package build is executed parallely'
  multitask :build_packages => [
    :st2python,
    :st2common
  ]

  desc 'Build python package (st2python)'
  task :st2python do |this|
    pipeline this.name do
      run hostname: opts[:buildnode] do |opts|
        command label: "package: #{this.short_name}", show_uuid: false

        execute :mkdir, "-p #{opts[:artifact_dir]}"
        with(opts.env) do
          within("#{opts[:basedir]}/packages/python") do
            execute :bash, "#{opts[:basedir]}/scripts/build_python.sh"
          end
        end
      end
    end
  end

  desc 'Build st2common package'
  task :st2common do |this|
  end
end
