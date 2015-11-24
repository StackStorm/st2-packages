# Prepopulate the wheelhouse.
# Run make wheelhouse for each of the packages, this invokes pip
# to fetch requirements and install them to a shared wheelhouse
# directory (/tmp/wheelhouse by default).
#

namespace :build do

  task_list = Array(pipeopts.packages).map {|p| "wheelhouse_#{p}"}

  task :wheelhouse => task_list

  rule %r/^wheelhouse_/ do |task|
    # Load specific context for a package name or 'st2'
    package_name = task.short_name.sub(/^wheelhouse_/, '')
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
            make :wheelhouse,  label: "wheelhouse: #{package_name}"
            make :bdist_wheel, label: "bdistwheel: #{package_name}"
          end
        end
      end
    end

  end
end
