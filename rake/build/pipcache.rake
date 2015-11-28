# Prepopulate ~/.pip/cache. Happens sequentially since it might fail
# if `pip install` invoked parallely for packages.
# Allows to run multiple package builds after this simultaneously.
#

namespace :build do

  task_list = Array(pipeopts.packages).map {|p| "pipcache_#{p}"}

  task :pipcache => task_list

  rule %r/^pipcache_/ do |task|
    # Load specific context for a package name or 'st2'
    package_name = task.short_name.sub(/^pipcache_/, '')
    context = pipeopts(package_name).empty? ? 'st2' : package_name

    pipeline context do
      run hostname: opts[:buildnode] do |opts|
        command show_uuid: false

        buildroot = opts.gitdir
        buildroot = File.join(buildroot, package_name) unless opts.standalone

        # Used to speed up make (hopefully) when run under pip
        env = opts.build_nproc.nil? ? opts.env : opts.env.merge('MAKEFLAGS' => '-j %s' % opts.build_nproc)

        with env do
          within buildroot do
            make :pipcache,  label: "pipcache: #{package_name}"
            make :bdist_wheel, label: "bdistwheel: #{package_name}"
          end
        end
      end
    end

  end
end
