%define package st2mistral
%define venv_name mistral
%define svc_user mistral
%define version %(echo -n "${MISTRAL_VERSION:-0.1}")
%define release %(echo -n "${MISTRAL_RELEASE:-1}")

%define _sourcedir ./
%define _builddir %{SOURCE0}
%include rpmspec/helpers.spec
%include rpmspec/package_venv.spec

Name: %{package}
Version: %{version}
Release: %{release}
Group: System/Management
License: Apache 2.0
Url: https://github.com/StackStorm/mistral
Source0: .
%if 0%{?use_st2python}
Requires: st2python, bash, procps
%else
Requires: bash, procps
%endif
Provides: openstack-mistral
Summary: st2 Mistral workflow service


%description
  Task orchestration and workflow engine with powerful strategies like parallelism, loops, retries,
  nested tasks, execution order capabilities. Rules defined in YAML, extended with YAQL expressions.

%define _builddir %{SOURCE0}

%install
  %default_install
  %pip_install_venv
  %service_install mistral mistral-api mistral-server
  make post_install DESTDIR=%{?buildroot}
  %{!?use_systemd:install -D -m644 conf/rhel-functions-sysvinit %{buildroot}/opt/stackstorm/mistral/share/sysvinit/functions}

  %cleanup_python_abspath

%prep
  rm -rf %{buildroot}
  mkdir -p %{buildroot}

%clean
  rm -rf %{buildroot}

%pre
  adduser --no-create-home --system --user-group %{svc_user} 2>/dev/null
  exit 0

%post
  %service_post mistral mistral-api mistral-server

%preun
  %service_preun mistral mistral-api mistral-server

%postun
  %service_postun mistral mistral-api mistral-server

%files
  %{_bindir}/mistral
  /opt/stackstorm/mistral
  %config(noreplace) %{_sysconfdir}/mistral/*
  %config(noreplace) %{_sysconfdir}/logrotate.d/mistral
  %attr(755, %{svc_user}, root) %{_localstatedir}/log/mistral
  %attr(755, %{svc_user}, root) %{_localstatedir}/run/mistral
%if 0%{?use_systemd}
  %{_unitdir}/mistral.service
  %{_unitdir}/mistral-api.service
  %{_unitdir}/mistral-server.service
%else
  %{_sysconfdir}/rc.d/init.d/mistral
  %{_sysconfdir}/rc.d/init.d/mistral-api
  %{_sysconfdir}/rc.d/init.d/mistral-server
%endif
