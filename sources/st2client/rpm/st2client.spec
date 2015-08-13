# Macros
%define version %(echo ${ST2PKG_VERSION:-0.1.0})
%define release %(echo ${ST2PKG_RELEASE:-1})
%define _builddir /root/code/st2client
%define svc_user st2
%define stanley_user stanley

%include %{_builddir}/../rpmspec/debian_helpers.spec

# Tags
Name: st2client
Version: %{version}
Release: %{release}
BuildArch: noarch
Summary: St2Client - StackStorm CLI utility
Group: System/Management
License: Apache
Url: https://github.com/StackStorm/st2
Source0: %{_builddir}

# Blocks
%description
  St2Client longer description.

%files
  /*
%install
  # We hate duplication right :)?, so let's use debian files
  %debian_dirs
  %debian_install
%make_install
%prep
  rm -rf %{buildroot}
  mkdir -p %{buildroot}
%clean
  rm -rf %{buildroot}

%pre
  # handle installation (not upgrade)
  if [ $1 = 1 ]; then
    [ -f /etc/logrotate.d/st2.disabled ] && mv -f /etc/logrotate.d/st2.disabled /etc/logrotate.d/st2
  fi
  adduser --no-create-home --system %{svc_user}
  adduser --user-group %{stanley_user}

%post
  chown %{svc_user}.%{svc_user} /var/log/st2

%postun
  # rpm has no purge option, so we leave this file
  [ -f /etc/logrotate.d/st2 ] && mv -f /etc/logrotate.d/st2 /etc/logrotate.d/st2.disabled
