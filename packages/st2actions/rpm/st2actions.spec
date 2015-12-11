%define package st2actions
%include ../rpmspec/st2pkg_toptags.spec

Summary: st2actions - StackStorm actions component
Requires: st2common = %{version}-%{release}, git

%description
  <insert long description, indented with spaces>

# Define worker name
%define worker_name %{!?use_systemd:st2actionrunner-worker}%{?use_systemd:st2actionrunner@}


%install
  %default_install
  %pip_install_venv
  %service_install st2notifier st2resultstracker st2actionrunner %{worker_name}
  make post_install DESTDIR=%{?buildroot}

%prep
  rm -rf %{buildroot}
  mkdir -p %{buildroot}

%clean
  rm -rf %{buildroot}

%post
  %service_post st2notifier st2resultstracker st2actionrunner %{worker_name}

%preun
  %service_preun st2notifier st2resultstracker st2actionrunner %{worker_name}

%postun
  %service_postun st2notifier st2resultstracker st2actionrunner %{worker_name}

%files
  %{_datadir}/python/%{name}
  %config(noreplace) %{_sysconfdir}/st2/*
%if 0%{?use_systemd}
  %{_unitdir}/st2actionrunner.service
  %{_unitdir}/%{worker_name}.service
  %{_unitdir}/st2notifier.service
  %{_unitdir}/st2resultstracker.service
%else
  %{_sysconfdir}/rc.d/init.d/st2actionrunner
  %{_sysconfdir}/rc.d/init.d/%{worker_name}
  %{_sysconfdir}/rc.d/init.d/st2notifier
  %{_sysconfdir}/rc.d/init.d/st2resultstracker
%endif
