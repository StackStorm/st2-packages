#!/usr/bin/env ruby
#
require 'rspec/core/rake_task'
require './rake/pipeline'

# Import build tasks
build_files = Dir.glob('rake/build/*.rake')
build_files.unshift('rake/build/environment').each do |file|
  import file
end

task :default => ['build:all', 'setup:all']
task :spec => 'spec:all'

namespace :build do
  desc 'Packages build entry task'
  task :all => [:upload_to_buildnode, :nproc, :checkout, :packages] do |task|
    pipeline do
      # Download artifacts to packagingrunner
      run hostname: opts[:buildnode] do |opts|
        rule = [ opts.artifact_dir, File.dirname(opts.artifact_dir) ]
        download!(*rule, recursive: true)
      end unless pipeopts[:docker_compose].to_i == 1

      run(:local) {|o| execute :ls, "-l #{o[:artifact_dir]}", verbosity: :debug}
    end
  end

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

  task :all => ['setup:all', *targets]

  targets.each do |target|
    RSpec::Core::RakeTask.new(target.to_sym) do |t|
      t.pattern = "./rake/spec/#{target}/*_spec.rb"
    end
  end
end
