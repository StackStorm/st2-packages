#!/usr/bin/env ruby
#
require './rake/pipeline'
import 'rake/build/environment'
Dir.glob('rake/build/*.rake').each { |r| import r }

task :default => 'build:build'


namespace :build do
  desc 'Packages build entry task'
  task :build => [:upload, :checkout, :packages] do |task|
    pipeline do
      run hostname: opts[:buildnode] do |opts|
        with opts.env do
          execute :ls, '-l $ARTIFACT_DIR', verbosity: :debug
        end
      end
    end
  end
end
