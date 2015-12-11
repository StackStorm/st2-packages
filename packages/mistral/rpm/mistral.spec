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
  %service_install %{name}
  make post_install DESTDIR=%{?buildroot}

%prep
  rm -rf %{buildroot}
  mkdir -p %{buildroot}

%clean
  rm -rf %{buildroot}

%pre
  adduser --no-create-home --system %{svc_user} 2>/dev/null
  exit 0

%post
  %service_post %{name}

%preun
  %service_preun %{name}

%postun
  %service_postun %{name}

%files
  %{_datadir}/python/%{name}
  %config(noreplace) %{_sysconfdir}/mistral/*
  %attr(755, %{svc_user}, %{svc_user}) %{_localstatedir}/log/mistral
%if 0%{?use_systemd}
  %{_unitdir}/%{name}.service
%else
  %{_sysconfdir}/rc.d/init.d/%{name}
%endif
