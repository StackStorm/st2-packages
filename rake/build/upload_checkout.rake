# Upload and checkout tasks
#

namespace :upload do

  ## Rule generates upload_to_* tasks (upload to remote nodes).
  #
  rule %r/^upload:to_/ do |task|
    nodename = task.short_name.sub(/^to_/, '')
    Rake::Task['upload:sources'].invoke(nodename)
  end

  ## Multitask which depends on parameterized upload_sources_* tasks.
  #  Dependents are evaluated based on pipeopts.upload_sources list.
  #
  source_tasks  = pipeopts.upload_sources.map {|s| :"%sources_#{s}" }
  multitask :sources, [:nodename] => source_tasks do |task|
    task.reenable
  end

  ## Rule generates %sources_* tasks.
  #  Uploads particular source to a remote node passed as argument.
  #
  rule %r/^%sources_/, [:nodename] do |task, args|
    # Task is restartable, since it's can be invoked with different arguments.
    task.reenable
    source_path = task.short_name.sub(/^%sources_/, '')
    host = pipeopts.send(args[:nodename]).to_s
    # Perform only if remote node hostname is provided
    unless host.empty?
      pipeline do
        run hostname: host do |opts|
          upload! source_path, opts[:basedir], recursive: true
        end
      end
    end
  end

  ## Multitask checks out git source of a package (if pipopts.checkout == true)
  #
  package_list = pipeopts.packages.select {|p| defined?(pipeopts(p).checkout)}
  multitask :checkout => package_list.map {|p| :"%checkout_#{p}"}

  ## Rule generates %checkout_* tasks.
  #  These tasks checkout required git sources.
  #
  rule %r/^%checkout_/ do |task|
    package = context = task.short_name.sub(/^%checkout_/, '')
    pipeline context do
      run hostname: opts[:buildnode] do |opts|
        command label: "checkout: #{package}", show_uuid: false
        with opts.env do
          execute :mkdir, '-p $ARTIFACT_DIR'
          within opts.basedir do
            if opts.checkout == 1
              execute :git, :clone, '--depth 1 -b $GITREV $GITURL $GITDIR'
            end
          end
        end
      end
    end
    # Invoke post checkout task if it's defined
    post_checkout = "package:post_checkout_#{package}"
    if Rake::Task.task_defined?(post_checkout)
      Rake::Task[post_checkout].invoke
    end
  end

end
