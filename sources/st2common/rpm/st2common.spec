%define package st2common
%define _sourcedir /root/code
%define specdir /root/code/rpmspec
%include %{specdir}/package_top.spec

BuildArch: noarch
Summary: St2Common - StackStorm shared files
%include %{specdir}/helpers.spec

# Blocks
%description
  Package contains core st2 packs and other common files. 

%install
  %default_install

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
  if [ ! -f /etc/st2/htpasswd ]; then
    touch /etc/st2/htpasswd
    chown %{svc_user}.%{svc_user} /etc/st2/htpasswd
    chmod 640 /etc/st2/htpasswd
  fi
  exit 0

%post
  chown %{svc_user}.%{svc_user} /var/log/st2

%postun
  # rpm has no purge option, so we leave this file
  [ -f /etc/logrotate.d/st2 ] && mv -f /etc/logrotate.d/st2 /etc/logrotate.d/st2.disabled
  exit 0

%files
  %defattr(-,root,root,-)
  %doc %{_datadir}/doc/st2/docs
  %config(noreplace) %{_sysconfdir}/st2/st2.conf
  %config(noreplace) %{_sysconfdir}/logrotate.d/st2
  %{_datadir}/doc/st2/examples
  %{_localstatedir}/log/st2
  /opt/stackstorm/packs/core
  /opt/stackstorm/packs/linux
  /opt/stackstorm/packs/packs
