%define package st2actions
%define _sourcedir /root/code
%define specdir /root/code/rpmspec
%include %{specdir}/package_top.spec

Summary: st2actions - StackStorm API component
Requires: st2common = %{version}-%{release}

%include %{specdir}/package_venv.spec
%include %{specdir}/helpers.spec

%description
  <insert long description, indented with spaces>

%install
  %default_install
  %pip_install_venv

  # systemd service file
  mkdir -p %{buildroot}%{_unitdir}
  install -m0644 %{SOURCE0}/rpm/st2actionrunner.service %{buildroot}%{_unitdir}/st2actionrunner.service
  install -m0644 %{SOURCE0}/rpm/st2actionrunner@.service %{buildroot}%{_unitdir}/st2actionrunner@.service
  install -m0644 %{SOURCE0}/rpm/st2notifier.service %{buildroot}%{_unitdir}/st2notifier.service
  install -m0644 %{SOURCE0}/rpm/st2resultstracker.service %{buildroot}%{_unitdir}/st2resultstracker.service
  make post_install DESTDIR=%{?buildroot}

%prep
  rm -rf %{buildroot}
  mkdir -p %{buildroot}

%clean
  rm -rf %{buildroot}

%pre
  %inst_venv_divertions

%post
  %systemd_post st2actionrunner st2actionrunner@ st2notifier st2resultstracker

%preun
  %systemd_preun st2actionrunner st2actionrunner@ st2notifier st2resultstracker

%postun
  %uninst_venv_divertions
  %systemd_postun

%files
  %{_datadir}/python/%{name}
  %config(noreplace) %{_sysconfdir}/%{name}/*
  %{_unitdir}/st2actionrunner.service
  %{_unitdir}/st2actionrunner@.service
  %{_unitdir}/st2notifier.service
  %{_unitdir}/st2resultstracker.service
