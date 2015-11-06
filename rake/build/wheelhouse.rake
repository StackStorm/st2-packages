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

        with opts.env do
          within buildroot do
            make :wheelhouse, label: "wheelhouse: %#{opts[:package_max_name]}s" % package_name

            # All st2* require st2common wheel so we put it into the wheelhouse
            if package_name == 'st2common'
              make :bdist_wheel, label: "wheelhouse: %#{opts[:package_max_name]}s" % package_name
            end
          end
        end
      end
    end

  end
end
