%define package st2bundle
%define _sourcedir /root/code
%define specdir /root/code/rpmspec
%define venv_name st2
%include %{specdir}/package_top.spec

Summary: StackStorm all components bundle
Conflicts: st2common

%include %{specdir}/package_venv.spec
%include %{specdir}/helpers.spec

%description
  Package is full standalone stackstorm installation including
  all components

%install
  %default_install
  %pip_install_venv
  make post_install DESTDIR=%{?buildroot}

  # systemd service file
  mkdir -p %{buildroot}%{_unitdir}
  install -m0644 %{SOURCE0}/rpm/st2actionrunner.service %{buildroot}%{_unitdir}/st2actionrunner.service
  install -m0644 %{SOURCE0}/rpm/st2actionrunner@.service %{buildroot}%{_unitdir}/st2actionrunner@.service
  install -m0644 %{SOURCE0}/rpm/st2api.service %{buildroot}%{_unitdir}/st2api.service
  install -m0644 %{SOURCE0}/rpm/st2auth.service %{buildroot}%{_unitdir}/st2auth.service
  install -m0644 %{SOURCE0}/rpm/st2exporter.service %{buildroot}%{_unitdir}/st2exporter.service
  install -m0644 %{SOURCE0}/rpm/st2notifier.service %{buildroot}%{_unitdir}/st2notifier.service
  install -m0644 %{SOURCE0}/rpm/st2resultstracker.service %{buildroot}%{_unitdir}/st2resultstracker.service
  install -m0644 %{SOURCE0}/rpm/st2rulesengine.service %{buildroot}%{_unitdir}/st2rulesengine.service
  install -m0644 %{SOURCE0}/rpm/st2sensorcontainer.service %{buildroot}%{_unitdir}/st2sensorcontainer.service

%prep
  rm -rf %{buildroot}
  mkdir -p %{buildroot}

%clean
  rm -rf %{buildroot}

%pre
  # handle installation (not upgrade)
  if [ $1 = 1 ]; then
    [ -f /etc/logrotate.d/st2.disabled ] && mv -f /etc/logrotate.d/st2.disabled /etc/logrotate.d/st2
  fi
  adduser --no-create-home --system %{svc_user} 2>/dev/null
  adduser --user-group %{stanley_user} 2>/dev/null
  exit 0

%post
  chown %{svc_user}.%{svc_user} /var/log/st2
  if [ ! -f /etc/st2/htpasswd ]; then
    touch /etc/st2/htpasswd
    chown %{svc_user}.%{svc_user} /etc/st2/htpasswd
    chmod 640 /etc/st2/htpasswd
  fi
  # enable services after install
  %systemd_post st2actionrunner st2api st2auth st2exporter st2notifier \
                st2resultstracker st2rulesengine st2sensorcontainer
  systemctl daemon-reload 1>/dev/null 2>&1 || :

%preun
  %systemd_preun st2actionrunner st2api st2auth st2exporter st2notifier \
                 st2resultstracker st2rulesengine st2sensorcontainer

%postun
  %systemd_postun
  # rpm has no purge option, so we leave this file
  [ -f /etc/logrotate.d/st2 ] && mv -f /etc/logrotate.d/st2 /etc/logrotate.d/st2.disabled
  exit 0

%files
  %defattr(-,root,root,-)
  %{_bindir}/*
  %doc %{_datadir}/doc/st2/docs
  %config(noreplace) %{_sysconfdir}/logrotate.d/st2
  %config(noreplace) %{_sysconfdir}/st2/*
  %{_datadir}/python/%{venv_name}
  %{_datadir}/doc/st2/examples
  %{_localstatedir}/log/st2
  /opt/stackstorm/packs/core
  /opt/stackstorm/packs/linux
  /opt/stackstorm/packs/packs
  %attr(755, %{svc_user}, %{svc_user}) /opt/stackstorm/exports
  %{_unitdir}/st2actionrunner.service
  %{_unitdir}/st2actionrunner@.service
  %{_unitdir}/st2api.service
  %{_unitdir}/st2auth.service
  %{_unitdir}/st2exporter.service
  %{_unitdir}/st2notifier.service
  %{_unitdir}/st2resultstracker.service
  %{_unitdir}/st2rulesengine.service
  %{_unitdir}/st2sensorcontainer.service
