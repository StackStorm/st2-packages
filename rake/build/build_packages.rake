# Package build tasks.
#
# St2 packages are build parallelly. However pip operation should go
# sequentially due to cuncurrency issues. So we start :wheelhouse
# ans :packages task parallelly, but package build is only fired
# as soon its wheelhouse has been pre-populated.
#
# We use the follwoing execution pattern:
#   p1 => [w1], p2 => [w1, w2], p3 => [w1, w2, w3] etc
#

namespace :build do
  # Get incremental wheeldeps, like [w1], [w1, w2] etc.
  wheelreq_proc = ->(tn) do
    package_name = tn.sub(/^build_/, '')
    wheelreq_list = pipeopts.packages.take_while {|p| p.to_s != package_name}
    wheelreq_list << package_name
    wheelreq_list.map {|r| "wheelhouse_#{r}"}
  end

  package_list = pipeopts.packages.map {|t| "build_#{t}"}
  multitask :packages => [:wheelhouse, *package_list]

  # We should built custom python for outdated OSes such as CentOS 6.
  build_dependencies = [ wheelreq_proc ].tap do |list|
    list.unshift('build:st2python') if pipeopts.st2python_enabled
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

  # Auxiliary task, used when ST2_PACKEGES="none", can used to build python only
  rule %r/^build_none$/ => build_dependencies

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
