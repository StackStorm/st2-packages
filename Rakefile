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
  env     :buildnode
  env     :testnodes
  passenv :debug_level, 1
  passenv :compose, 1
  passenv :artifact_dir, '/root/build'
  passenv :st2_giturl,   'https://github.com/StackStorm/st2'
  passenv :st2_gitrev,   'master'
  passenv :st2_gitdir,    make_tmpname('st2-')
  passenv :st2pkg_version
  passenv :st2pkg_release, 1
  passenv :st2_python, 0
  passenv :st2_python_version, '2.7.10'
  passenv :st2_python_relase, 1
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
