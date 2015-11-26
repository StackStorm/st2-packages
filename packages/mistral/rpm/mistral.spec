%define package mistral
%define svc_user mistral
%define version %(echo -n "${MISTRAL_VERSION:-0.1}")
%define release %(echo -n "${MISTRAL_RELEASE:-1}")

%define _sourcedir ./
%include rpmspec/helpers.spec
%include rpmspec/package_venv.spec

Name: %{package}
Version: %{version}
Release: %{release}
Group: System/Management
License: Apache
Url: https://github.com/StackStorm/mistral
Source0: .
Summary: Mistral workflow service

%define _builddir %{SOURCE0}

%description
  <insert long description, indented with spaces>

%install
  %default_install
  %pip_install_venv

  # systemd service file
  mkdir -p %{buildroot}%{_unitdir}
  install -m0644 %{SOURCE0}/rpm/%{name}.service %{buildroot}%{_unitdir}/%{name}.service
  make post_install DESTDIR=%{buildroot}

%prep
  rm -rf %{buildroot}
  mkdir -p %{buildroot}

%clean
  rm -rf %{buildroot}

%pre
  adduser --no-create-home --system %{svc_user} 2>/dev/null
  exit 0

%post
  %systemd_post %{name}
  systemctl --no-reload enable %{name} >/dev/null 2>&1 || :

%preun
  %systemd_preun %{name}

%postun
  %systemd_postun

%files
  %{_datadir}/python/%{name}
  %config(noreplace) %{_sysconfdir}/mistral/*
  %{_unitdir}/%{name}.service
  %attr(755, %{svc_user}, %{svc_user}) %{_localstatedir}/log/mistral
