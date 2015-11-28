# Package build tasks.
#
# St2 packages are build parallelly. However pip operation should go
# sequentially due to cuncurrency issues.
# We use the follwoing execution pattern:
#   b1 => [p1], b2 => [p1, p2], b3 => [p1, p2, p3] etc
#
# Exp.: For example buil 2 starts after pip dependancies installed for
# packages 1 and 2
#

namespace :build do
  pipcachereq_proc = ->(tn) do
    package_name = tn.sub(/^build_/, '')
    pipcachereq_list = Array(pipeopts.packages).take_while {|p| p.to_s != package_name}
    pipcachereq_list << package_name
    pipcachereq_list.map {|r| "pipcache_#{r}"}
  end

  package_list = Array(pipeopts.packages).map {|t| "build_#{t}"}
  multitask :packages => [:pipcache, *package_list]

  # We should built custom python for outdated OSes such as CentOS 6.
  build_dependencies = [ pipcachereq_proc ]
  if pipeopts('st2python')[:st2_python].to_i == 1
    build_dependencies.unshift('build:st2python')
  end

  desc 'Build custom python version (st2python)'
  task :st2python do |task|
    pipeline 'st2python' do
      run hostname: opts[:buildnode] do |opts|
        command label: 'package: st2python', show_uuid: false

        with opts.env do
          within File.join(opts.basedir, 'packages/python') do
            execute :bash, "$BASEDIR/scripts/build_python.sh"
          end

          within opts.artifact_dir do
            execute :bash, "$BASEDIR/scripts/install_os_packages.sh st2python"
          end
        end
      end
    end
  end

  # Generate build task for packages
  rule %r/^build_/ => build_dependencies do |task|
    # Load specific context for a package name or 'st2'
    package_name = task.short_name.sub(/^build_/, '')
    context = pipeopts(package_name).empty? ? 'st2' : package_name

    pipeline context do
      run hostname: opts[:buildnode] do |opts|
        command label: "package: #{package_name}", show_uuid: false

        buildroot = opts.gitdir
        buildroot = File.join(buildroot, package_name) unless opts.standalone

        with opts.env do
          within buildroot do
            make :changelog
            execute :bash, "$BASEDIR/scripts/build_os_package.sh #{package_name}"
          end
        end
      end
    end
  end

end
