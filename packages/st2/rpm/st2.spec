%define package st2
%define venv_name st2
%define svc_user st2
%define stanley_user stanley
%define packs_group st2packs

%include ../rpmspec/st2pkg_toptags.spec

%if 0%{?epoch}
Epoch: %{epoch}
%endif

%if 0%{?rhel} == 8
%global _build_id_links none
%endif

Requires: openssl-devel, libffi-devel, git, pam, openssh-server, openssh-clients, bash, setup
%if 0%{?rhel} == 8
Requires: python38-devel
%endif
%if 0%{?rhel} == 9
Requires: python3-devel
%endif

# EL8 requires a few python packages available within 'BUILDROOT' when outside venv
# These are in the el8 packagingbuild dockerfile
# Reference https://fossies.org/linux/ansible/packaging/rpm/ansible.spec
%if 0%{?rhel} == 8
# Will use the python3 stdlib venv
BuildRequires: python38-devel
BuildRequires: python38-setuptools
%endif
%if 0%{?rhel} == 9
BuildRequires: python3-devel
BuildRequires: python3-setuptools
%endif

# Apply this to both RHEL 8 and RHEL 9
%if 0%{?rhel} > 7
# By default the RPM helper scripts will try to generate Requires: section which lists every
# Python dependencies. That process / script works by recursively scanning all the package Python
# dependencies which is very slow (5-6 minutes).
# Our package bundles virtualenv with all the dependendencies and doesn't rely on this metadata
# so we skip that step to vastly speed up the build.
# Technically we also don't Require or Provide any of those libraries auto-detected by that script
# because those are only used internally inside a package specific virtual environment.
# See https://github.com/StackStorm/st2-packages/pull/697#issuecomment-808971874 and that PR for
# more details.
# That issue was found by enabling rpmbuild -vv flag.
%undefine __pythondist_provides
%undefine __pythondist_requires
%undefine __python_provides
%undefine __python_requires
%endif

Summary: StackStorm all components bundle
Conflicts: st2common

%description
  Package is full standalone stackstorm installation including
  all components

# Define worker name
%define worker_name st2actionrunner@

# WORKAROUND: RockyLinux9 doesn't have a python virtualenv rpm so it's installed during build as a dependency with pip.
%if 0%{?rhel} == 9
%build
  pip install virtualenv
%endif

%install
  %default_install
  %pip_install_venv
  %service_install st2actionrunner %{worker_name} st2api st2stream st2auth st2notifier st2workflowengine
  %service_install st2rulesengine st2timersengine st2sensorcontainer st2garbagecollector
  %service_install st2scheduler
  make post_install DESTDIR=%{buildroot}

# We build cryptography for RHEL8/RHEL9, and this can contain buildroot path in the
# built .so files. We use strip on these libraries so that there are no
# references to the buildroot in the st2 rpm
%if 0%{?rhel} > 7
  %cleanup_so_abspath
%endif
  %cleanup_python_abspath

%prep
  rm -rf %{buildroot}
  mkdir -p %{buildroot}

%clean
  rm -rf %{buildroot}

%pre
  %include rpm/preinst_script.spec

%post
  %service_post st2actionrunner st2api st2stream st2auth st2notifier st2workflowengine
  %service_post st2rulesengine st2timersengine st2sensorcontainer st2garbagecollector
  %service_post st2scheduler
  %include rpm/postinst_script.spec

%preun
  %service_preun st2actionrunner %{worker_name} st2api st2stream st2auth st2notifier st2workflowengine
  %service_preun st2rulesengine st2timersengine st2sensorcontainer st2garbagecollector
  %service_preun st2scheduler

%postun
  %service_postun st2actionrunner %{worker_name} st2api st2stream st2auth st2notifier st2workflowengine
  %service_postun st2rulesengine st2timersengine st2sensorcontainer st2garbagecollector
  %service_postun st2scheduler
  # Remove st2 logrotate config, since there's no analog of apt-get purge available
  if [ $1 -eq 0 ]; then
    rm -f /etc/logrotate.d/st2
  fi

%files
  %defattr(-,root,root,-)
  /opt/stackstorm/%{venv_name}
  %{_bindir}/*
  %config %{_sysconfdir}/bash_completion.d/st2
  %config(noreplace) %{_sysconfdir}/logrotate.d/st2
  %config(noreplace) %attr(600, %{svc_user}, %{svc_user}) %{_sysconfdir}/st2/htpasswd
  %config(noreplace) %{_sysconfdir}/st2/*
  %{_datadir}/doc/st2
  %attr(755, %{svc_user}, root) /opt/stackstorm/configs
  %attr(755, %{svc_user}, root) /opt/stackstorm/exports
  %attr(755, %{svc_user}, root) /opt/stackstorm/overrides
  %attr(755, %{svc_user}, root) %{_localstatedir}/log/st2
  %attr(755, %{svc_user}, root) %{_localstatedir}/run/st2
  %attr(775, root, %{packs_group}) /opt/stackstorm/packs/*
  %attr(775, root, %{packs_group}) /usr/share/doc/st2/examples
  %attr(775, root, %{packs_group}) /opt/stackstorm/virtualenvs
  %{_unitdir}/st2actionrunner.service
  %{_unitdir}/%{worker_name}.service
  %{_unitdir}/st2api.service
  %{_unitdir}/st2stream.service
  %{_unitdir}/st2auth.service
  %{_unitdir}/st2notifier.service
  %{_unitdir}/st2rulesengine.service
  %{_unitdir}/st2sensorcontainer.service
  %{_unitdir}/st2garbagecollector.service
  %{_unitdir}/st2timersengine.service
  %{_unitdir}/st2workflowengine.service
  %{_unitdir}/st2scheduler.service
  /usr/lib/systemd/system-generators/st2api-generator
  /usr/lib/systemd/system-generators/st2auth-generator
  /usr/lib/systemd/system-generators/st2stream-generator
