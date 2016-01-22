%define package st2mistral
# version is hardcoded so far
%define version 0.1.0
%define release %(echo -n "${ST2PKG_RELEASE:-1}")

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
# st2 mistral bundled package provides virtual name (openstack-mistral),
# so we require trying to be compatible with github/openstack
Requires: openstack-mistral
Summary: StackStorm plugins for OpenStack Mistral


%description
  <insert long description, indented with spaces>

%define _builddir %{SOURCE0}

%install
  %default_install

%prep
  rm -rf %{buildroot}
  mkdir -p %{buildroot}

%post
  . /usr/share/st2mistral/helpers/setup_with_pip.sh
  st2mistral install

%preun
  . /usr/share/st2mistral/helpers/setup_with_pip.sh
  st2mistral uninstall

%clean
  rm -rf %{buildroot}

%files
  %{_datadir}/st2mistral/*
