%define package st2auth
%include ../rpmspec/st2pkg_toptags.spec

Summary: St2Auth - StackStorm authentication service component
Requires: st2common = %{version}-%{release}

%description
  <insert long description, indented with spaces>

%install
  %default_install
  %pip_install_venv
  %service_install %{name}
  make post_install DESTDIR=%{?buildroot}
  # clean up absolute path in record file, so that /usr/bin/check-buildroot doesn't fail
  find /root/rpmbuild/BUILDROOT/%{package}* -name RECORD -exec sed -i '/\/root\/rpmbuild.*$/d' '{}' ';'

%prep
  rm -rf %{buildroot}
  mkdir -p %{buildroot}

%clean
  rm -rf %{buildroot}

%post
  %service_post %{name}

%preun
  %service_preun %{name}

%postun
  %service_postun %{name}
  %systemd_postun_with_restart

%files
  %{_datadir}/python/%{name}
  %config(noreplace) %{_sysconfdir}/st2/*
%if 0%{?use_systemd}
  %{_unitdir}/%{name}.service
%else
  %{_sysconfdir}/rc.d/init.d/%{name}
%endif
