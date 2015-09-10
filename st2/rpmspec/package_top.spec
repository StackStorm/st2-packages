# ! must be defined before include
#   - package
#   - _sourcedir

%define version %(echo ${ST2PKG_VERSION:-0.1.0})
%define release %(echo ${ST2PKG_RELEASE:-1})
%define svc_user st2
%define stanley_user stanley

Name: %{package}
Version: %{version}
Release: %{release}
Group: System/Management
License: Apache
Url: https://github.com/StackStorm/st2
Source0: %{package}

%define _builddir %{SOURCE0}
