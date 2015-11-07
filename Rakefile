#!/usr/bin/env ruby
#
require './rake/pipeline'
import 'environment'
Dir.glob('rake/build/*.rake').each { |r| import r }

task :default => 'build:build'

namespace :build do
  desc 'Packages build entry task'
  task :build => [:upload, :nproc, :checkout, :packages] do |task|
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
