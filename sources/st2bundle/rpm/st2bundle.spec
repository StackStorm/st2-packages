%define package st2bundle
%define _sourcedir /root/code
%define specdir /root/code/rpmspec
%define venv_name st2
%include %{specdir}/package_top.spec

Summary: StackStorm all components bundle

%include %{specdir}/package_venv.spec
%include %{specdir}/helpers.spec

%description
  Package is full standalone stackstorm installation including
  all components

%install
  %default_install
  %pip_install_venv
  make post_install DESTDIR=%{?buildroot}

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
  exit 0

%postun
  # rpm has no purge option, so we leave this file
  [ -f /etc/logrotate.d/st2 ] && mv -f /etc/logrotate.d/st2 /etc/logrotate.d/st2.disabled
  exit 0

%files
  %defattr(-,root,root,-)
  %{_bindir}/*
  %doc %{_datadir}/doc/st2/docs
  %config(noreplace) %{_sysconfdir}/st2/st2.conf
  %config(noreplace) %{_sysconfdir}/logrotate.d/st2
  %{_datadir}/python/%{name}
  %{_datadir}/doc/st2/examples
  %{_localstatedir}/log/st2
  /opt/stackstorm/packs/core
  /opt/stackstorm/packs/linux
  /opt/stackstorm/packs/packs
