%define package st2
%define venv_name st2
%define svc_user st2
%define stanley_user stanley
%define packs_group st2packs

%include ../rpmspec/st2pkg_toptags.spec

%if 0%{?epoch}
Epoch: %{epoch}
%endif

%if 0%{?rhel} >= 8
%global _build_id_links none
%endif

Requires: python3-devel, openssl-devel, libffi-devel, git, pam, openssh-server, openssh-clients, bash, setup

# EL8 requires a few python packages available within 'BUILDROOT' when outside venv
# These are in the el8 packagingbuild dockerfile
# Reference https://fossies.org/linux/ansible/packaging/rpm/ansible.spec
%if 0%{?rhel} >= 8
# Will use the python3 stdlib venv
BuildRequires: python3-devel
BuildRequires: python3-setuptools
%endif  # Requires for RHEL 8

Summary: StackStorm all components bundle
Conflicts: st2common

%description
  Package is full standalone stackstorm installation including
  all components

# Define worker name
%define worker_name st2actionrunner@


%install
  %default_install
  %pip_install_venv
  %service_install st2actionrunner %{worker_name} st2api st2stream st2auth st2notifier st2workflowengine
  %service_install st2resultstracker st2rulesengine st2timersengine st2sensorcontainer st2garbagecollector
  %service_install st2scheduler
  make post_install DESTDIR=%{buildroot}

# We build cryptography for EL8, and this can contain buildroot path in the
# built .so files. We use strip on these libraries so that there are no
# references to the buildroot in the st2 rpm
%if 0%{?rhel} == 8
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
  %service_post st2resultstracker st2rulesengine st2timersengine st2sensorcontainer st2garbagecollector
  %service_post st2scheduler
  %include rpm/postinst_script.spec

%preun
  %service_preun st2actionrunner %{worker_name} st2api st2stream st2auth st2notifier st2workflowengine
  %service_preun st2resultstracker st2rulesengine st2timersengine st2sensorcontainer st2garbagecollector
  %service_preun st2scheduler

%postun
  %service_postun st2actionrunner %{worker_name} st2api st2stream st2auth st2notifier st2workflowengine
  %service_postun st2resultstracker st2rulesengine st2timersengine st2sensorcontainer st2garbagecollector
  %service_postun st2scheduler
  # Remove st2 logrotate config, since there's no analog of apt-get purge available
  if [ $1 -eq 0 ]; then
    [ ! -f /etc/logrotate.d/st2 ] || rm /etc/logrotate.d/st2
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
  %attr(755, %{svc_user}, root) %{_localstatedir}/log/st2
  %attr(755, %{svc_user}, root) %{_localstatedir}/run/st2
  %attr(775, root, %{packs_group}) /opt/stackstorm/packs/*
  %attr(775, root, %{packs_group}) /usr/share/doc/st2/examples
  %attr(775, root, %{packs_group}) /opt/stackstorm/virtualenvs
  %{_unitdir}/st2actionrunner.service
  %{_unitdir}/%{worker_name}.service
  %{_unitdir}/st2api.service
  %{_unitdir}/st2api.socket
  %{_unitdir}/st2stream.service
  %{_unitdir}/st2stream.socket
  %{_unitdir}/st2auth.service
  %{_unitdir}/st2auth.socket
  %{_unitdir}/st2notifier.service
  %{_unitdir}/st2resultstracker.service
  %{_unitdir}/st2rulesengine.service
  %{_unitdir}/st2sensorcontainer.service
  %{_unitdir}/st2garbagecollector.service
  %{_unitdir}/st2timersengine.service
  %{_unitdir}/st2workflowengine.service
  %{_unitdir}/st2scheduler.service
