#!/usr/bin/env ruby
#
require 'rspec/core/rake_task'
require './rake/pipeline'
import 'rake/build/environment'
Dir.glob('rake/build/*.rake').each { |r| import r }

task :default => ['build:build', 'setup:all']
task :spec => 'spec:all'

namespace :build do
  desc 'Packages build entry task'
  task :build => [:upload_to_buildnode, :nproc, :checkout, :packages] do |task|
    pipeline do
      run hostname: opts[:buildnode] do |opts|
        with opts.env do
          execute :ls, '-l $ARTIFACT_DIR', verbosity: :debug
        end
      end
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


namespace :setup do
  task :all => [:upload_artifacts, :install_artifacts]

  # We don't need to upload artifacts on docker-compose,
  # since they are passed through in a volume.
  task :upload_artifacts do
    unless pipeopts['docker_compose'].to_i == 1
      pipeline do
        # download artifacts to packagingrunner
        run hostname: opts[:buildnode] do
          within File.dirname(opts.artifact_dir) do
            download! opts.artifact_dir, './', recursive: true
          end
        end

        # upload artifcats to testnode
        run hostname: opts[:testnode] do
          within File.dirname(opts.artifact_dir) do
            upload! opts.artifact_dir, './', recursive: true
          end
        end
      end
    end
  end

  task :install_artifacts => 'build:upload_to_testnode' do
    pipeline do
      run hostname: opts[:testnode] do |opts|
        package_list = Array(opts.packages)
        if opts[:testmode] == 'packages'
          package_list.delete(:st2bundle)
        elsif origin_list.include?(:st2bundle)
          package_list.select! {|p| not p.to_s.start_with?('st2')}
          package_list << :st2bundle
        end

        with opts.env do
          within opts.artifact_dir do
            execute :bash, "$BASEDIR/scripts/install_os_packages.sh #{package_list.join(' ')}"
          end
        end
      end
    end
  end
end


# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# SPECS SHOULD BE REWRITEN COMPLETLY THEY ARE SO BAD.
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
