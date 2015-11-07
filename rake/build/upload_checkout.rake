# Upload and checkout tasks
#

namespace :build do

  desc 'Parallely upload given sources onto the remotes'
  multitask :upload => pipeopts[:uploads].map {|s| "upload_#{s}"}

  rule %r/upload_/ do |task|
    pipeline do
      run hostname: opts[:buildnode] do |opts|
        source = task.short_name.sub(/upload_/, '')
        upload! source, opts[:basedir], recursive: true
      end
    end
  end

  # go throug all packages and get checkout option
  checkout_contexts = Array(pipeopts.packages).map do |package|
    package_name = package.to_s
    context = pipeopts(package_name).empty? ? 'st2' : package_name
    pipeopts(context).checkout
  end.flatten.uniq

  desc 'Parallely checkout sources from github.com'
  multitask :checkout => checkout_contexts.map {|c| :"checkout_#{c}"}

  checkout_contexts.each do |context|
    task :"checkout_#{context}" do
      pipeline context.to_s do
        run hostname: opts[:buildnode] do |opts|
          command label: "checkout: #{context}", show_uuid: false

          package_updates = "packages/#{context}"
          package_updates << '/' if opts.standalone

          with opts.env do
            execute :mkdir, '-p $ARTIFACT_DIR'
            within opts.basedir do
              execute :git, :clone, '--depth 1 -b $GITREV $GITURL $GITDIR'
              execute :cp,  "-r rpmspec/ #{package_updates}* $GITDIR"
            end
          end
        end
      end
    end
  end

end
