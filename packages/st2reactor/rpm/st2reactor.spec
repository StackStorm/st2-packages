%define package st2reactor
%include ../rpmspec/st2pkg_toptags.spec

Summary: St2Reactor - StackStorm sensors component
Requires: st2common = %{version}-%{release}

%description
  <insert long description, indented with spaces>

%install
  %default_install
  %pip_install_venv
  %service_install st2rulesengine st2sensorcontainer st2garbagecollector
  make post_install DESTDIR=%{?buildroot}
  # clean up absolute path in record file, so that /usr/bin/check-buildroot doesn't fail
  find /root/rpmbuild/BUILDROOT/%{package}* -name RECORD -exec sed -i '/\/root\/rpmbuild.*$/d' '{}' ';'

%prep
  rm -rf %{buildroot}
  mkdir -p %{buildroot}

%clean
  rm -rf %{buildroot}

%post
  %service_post st2rulesengine st2sensorcontainer st2garbagecollector

%preun
  %service_preun st2rulesengine st2sensorcontainer st2garbagecollector

%postun
  %service_postun st2rulesengine st2sensorcontainer st2garbagecollector

%files
  %{_bindir}/*
  %{_datadir}/python/%{name}
  %config(noreplace) %{_sysconfdir}/st2/*
%if 0%{?use_systemd}
  %{_unitdir}/st2rulesengine.service
  %{_unitdir}/st2sensorcontainer.service
  %{_unitdir}/st2garbagecollector.service
%else
  %{_sysconfdir}/rc.d/init.d/st2rulesengine
  %{_sysconfdir}/rc.d/init.d/st2sensorcontainer
  %{_sysconfdir}/rc.d/init.d/st2garbagecollector
%endif
