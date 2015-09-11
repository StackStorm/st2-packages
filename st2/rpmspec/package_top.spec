# !!! Following list of variables must be defined before this file is included.
#   - package

%include ../rpmspec/helpers.spec
%include ../rpmspec/package_venv.spec

%define _sourcedir ../
%define svc_user st2
%define stanley_user stanley

# ST2 component is being processed
#
%{!?version: %define version %(echo "${ST2PKG_VERSION:-%{st2pkg_version}}")}
%{!?release: %define release 1}
%{!?url: %define url https://github.com/StackStorm/st2}

Name: %{package}
Version: %{version}
Release: %{release}
Group: System/Management
License: Apache
Url: %{url}
Source0: %{package}

%define _builddir %{SOURCE0}
