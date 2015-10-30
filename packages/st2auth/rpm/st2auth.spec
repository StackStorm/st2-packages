%define package st2auth
%include ../rpmspec/st2pkg_toptags.spec

Summary: St2Auth - StackStorm authentication service component
Requires: st2common = %{version}-%{release}

%description
  <insert long description, indented with spaces>

%install
  %default_install
  %pip_install_venv

# systemd service file
%if %{use_systemd}
  install -D -p -m0644 %{SOURCE0}/rpm/%{name}.service %{buildroot}%{_unitdir}/%{name}.service
%else
  install -D -p -m0755 %{SOURCE0}/rpm/%{name}.init %{buildroot}%{_sysconfdir}/rc.d/init.d/%{name}
%endif
  mkdir -p %{buildroot}%{_unitdir}
  make post_install DESTDIR=%{?buildroot}

%prep
  rm -rf %{buildroot}
  mkdir -p %{buildroot}

%clean
  rm -rf %{buildroot}

%post
%if %{use_systemd}
  %systemd_post %{name}
  # enable to enforce the policy, which seems to be disabled by default
  systemctl --no-reload enable %{name} >/dev/null 2>&1 || :
%else
  /sbin/chkconfig --add %{name} || :
%endif

%preun
  %systemd_preun %{name}
%if ! %{use_systemd}
  /sbin/service %{name} stop &>/dev/null || :
  /sbin/chkconfig --del %{name} &>/dev/null || :
%endif

%postun
%if %{use_systemd}
  %systemd_postun_with_restart
%else
  if [ $1 -ge 1 ]; then
    # package upgrade!
    /sbin/service %{name} try-restart &>/dev/null || :
  fi
%endif

%files
  %{_datadir}/python/%{name}
  %config(noreplace) %{_sysconfdir}/st2/*
%if %{use_systemd}
  %{_unitdir}/%{name}.service
%else
  %{_sysconfdir}/rc.d/init.d/%{name}
%endif
