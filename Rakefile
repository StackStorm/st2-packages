#!/usr/bin/env ruby
require './rake/pipeline'
require 'pp'

ShellOut.run

task :default => :st2python do
  ShellOut.finalize
end

pipeopts do
  basedir '/root'
  ssh_options({
    keys: %w(/root/.ssh/busybee),
    auth_methods: %w(publickey)
  })
  env   :buildnode
  set   :debug_level, 1
  set   :compose, 1
  set   :artifact_dir, '/root/build'
  set   :st2_giturl,   'https://github.com/StackStorm/st2'
  set   :st2_gitrev,   'master'
  set   :st2_gitdir,    make_tmpname('st2-')
  set   :st2pkg_version
  set   :st2pkg_release, 1
  set   :st2_python, 0
  set   :st2_python_version, '2.7.10'
  set   :st2_python_relase, 1
end

task :st2python do |this|
  pipeopts this.name do
    script "#{basedir}/build_python.sh"
  end

  pipeline this.name do
    run hostname: opts.buildnode do |opts|
      command labal: 'fukku'
      within(opts.basedir) do
        puts opts.buildnode
        execute :ls, '-l'
      end
    end
    run :local do
      execute :hostname
    end
  end
end
