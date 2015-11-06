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

  desc 'Parallely checkout sources from github.com'
  multitask :checkout => pipeopts[:checkout]

  rule %r/(st2|mistral)/ do |task|
    # Load specific context for a package name or 'st2'
    package_name = task.short_name.sub(/^wheelhouse_/, '')
    context = pipeopts(package_name).empty? ? 'st2' : package_name

    pipeline context do
      run hostname: opts[:buildnode] do |opts|
        command label: "checkout: #{package_name}", show_uuid: false

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
