# package must be defined before inclusion!

%define _sourcedir ../
%include ../rpmspec/helpers.spec
%include ../rpmspec/package_venv.spec

%define version %(echo "${ST2PKG_VERSION:-%{st2pkg_version}}")
%define release %(echo "${ST2PKG_RELEASE:-1}")

Name: %{package}
Version: %{version}
Release: %{release}
Group: System/Management
License: Apache
Url: https://github.com/StackStorm/st2
Source0: %{package}

%define _builddir %{SOURCE0}
