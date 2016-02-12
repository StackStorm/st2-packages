#!/usr/bin/env ruby
#
require 'rspec/core/rake_task'
require './rake/pipeline'
require './rake/build/environment'

# Import build tasks
build_files = Dir.glob('rake/build/*.rake')
build_files.each { |file| import file }

task :default => ['build:all', 'setup:all']

# Hopefully it will speed up make calls from pip
desc 'Store build node nproc value'
task :nproc do
  pipeline do
    run hostname: opts[:buildnode] do
      capture(:nproc).strip rescue nil
    end
  end.tap do |nproc|
    pipeopts { build_nproc nproc }
  end
end

namespace :build do
  ## Default build task, triggers the whole build task pipeline.
  #
  task :all => [:nproc, 'upload:to_buildnode', 'upload:checkout', 'build:packages'] do
    pipeline do
      run(:local) {|o| execute :ls, "-l #{o[:artifact_dir]}", verbosity: :debug}
    end
  end

  ## Packages task and build multitask (which invokes builds concurrently)
  #
  task :packages => [:prebuild, :build]
  multitask :build => pipeopts.packages.map {|p| "package:#{p}"}

  ## Prebuild task invokes all packages prebuild tasks.
  #  These task are executed sequentially (we require this not to mess up pip)!
  task :prebuild do
    pipeopts.packages.each do |p|
      task = "package:prebuild_#{p}"
      if Rake::Task.task_defined?(task)
        Rake::Task[task].invoke
      end
    end
  end
end

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# SPECS SHOULD BE REWRITEN COMPLETLY THEY ARE SO BAD AND UGLY.
# But the are left for now since the do its work and we need
# to ship packages faster.
#
namespace :spec do
  targets = []

  Dir.glob('./rake/spec/*').each do |dir|
    next unless File.directory?(dir)
    targets << File.basename(dir)
  end

  task :all => targets

  targets.each do |target|
    RSpec::Core::RakeTask.new(target.to_sym) do |t|
      t.pattern = "./rake/spec/#{target}/*_spec.rb"
    end
  end
end
