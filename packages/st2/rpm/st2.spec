%define package st2
%define venv_name st2
%define svc_user st2
%define stanley_user stanley
%define packs_group st2packs
%define epoch %(_epoch=`echo $ST2PKG_VERSION | grep -q dev || echo 1`; echo "${_epoch:-0}")

%include ../rpmspec/st2pkg_toptags.spec

%if 0%{?epoch}
Epoch: %{epoch}
%endif

%if 0%{?use_st2python}
Requires: st2python, python-devel, openssl-devel, libffi-devel, git, pam, openssh-server, openssh-clients, bash, setup
%else
Requires: python3-devel openssl-devel, libffi-devel, git, pam, openssh-server, openssh-clients, bash, setup
%endif

# EL8 requires a few python packages available within 'BUILDROOT' when outside venv
# These are in the el8 packagingbuild dockerfile
# Reference https://fossies.org/linux/ansible/packaging/rpm/ansible.spec
%if 0%{?rhel} >= 8
# Will use the python3 stdlib venv
BuildRequires: python3-devel
BuildRequires: python3-setuptools
Requires: python3-virtualenv
BuildRequires: python3-virtualenv
%endif  # Requires for RHEL 8

Summary: StackStorm all components bundle
Conflicts: st2common

%description
  Package is full standalone stackstorm installation including
  all components

# Define worker name
%define worker_name %{!?use_systemd:st2actionrunner-worker}%{?use_systemd:st2actionrunner@}


%install
  %default_install
  %pip_install_venv
  %service_install st2actionrunner %{worker_name} st2api st2stream st2auth st2notifier st2workflowengine
  %service_install st2resultstracker st2rulesengine st2timersengine st2sensorcontainer st2garbagecollector
  %service_install st2scheduler
  make post_install DESTDIR=%{buildroot}
  %{!?use_systemd:install -D -m644 conf/rhel-functions-sysvinit %{buildroot}/opt/stackstorm/st2/share/sysvinit/functions}

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
%if 0%{?use_systemd}
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
%else
  %{_sysconfdir}/rc.d/init.d/st2actionrunner
  %{_sysconfdir}/rc.d/init.d/%{worker_name}
  %{_sysconfdir}/rc.d/init.d/st2api
  %{_sysconfdir}/rc.d/init.d/st2stream
  %{_sysconfdir}/rc.d/init.d/st2auth
  %{_sysconfdir}/rc.d/init.d/st2notifier
  %{_sysconfdir}/rc.d/init.d/st2resultstracker
  %{_sysconfdir}/rc.d/init.d/st2rulesengine
  %{_sysconfdir}/rc.d/init.d/st2timersengine
  %{_sysconfdir}/rc.d/init.d/st2sensorcontainer
  %{_sysconfdir}/rc.d/init.d/st2garbagecollector
  %{_sysconfdir}/rc.d/init.d/st2workflowengine
  %{_sysconfdir}/rc.d/init.d/st2scheduler
%endif
