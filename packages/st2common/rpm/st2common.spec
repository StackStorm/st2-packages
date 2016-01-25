%define package st2common
%define svc_user st2
%define stanley_user stanley
%include ../rpmspec/st2pkg_toptags.spec

Summary: St2Common - StackStorm shared files

%description
  <insert long description, indented with spaces>

%install
  %default_install
  %pip_install_venv
  make post_install DESTDIR=%{?buildroot}
  # clean up absolute path in record file, so that /usr/bin/check-buildroot doesn't fail
  find /root/rpmbuild/BUILDROOT/%{package}* -name RECORD -exec sed -i '/\/root\/rpmbuild.*$/d' '{}' ';'

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
  %config(noreplace) %{_sysconfdir}/st2/st2.conf
  %config(noreplace) %{_sysconfdir}/logrotate.d/st2
  %{_datadir}/python/%{name}
  %{_datadir}/doc/st2/examples
  %attr(755, %{svc_user}, %{svc_user}) %{_localstatedir}/log/st2
  %attr(755, %{svc_user}, %{svc_user}) /opt/stackstorm/packs/core
  %attr(755, %{svc_user}, %{svc_user}) /opt/stackstorm/packs/linux
  %attr(755, %{svc_user}, %{svc_user}) /opt/stackstorm/packs/packs
