# Macros
%define version %(echo ${ST2PKG_VERSION:-0.1.0})
%define release %(echo ${ST2PKG_RELEASE:-1})
%define _builddir /root/code/st2client
%define svc_user st2
%define stanley_user stanley

%include %{_builddir}/../rpmspec/debian_helpers.spec

# venv
%define wheel_dir %(echo ${WHEELDIR:-/tmp/wheelhouse})
%define venv_cmd virtualenv
%define venv_name st2client
%define venv_install_dir usr/share/python/%{venv_name}
%define venv_dir %{buildroot}/%{venv_install_dir}
%define venv_bin %{venv_dir}/bin
%define venv_python %{venv_bin}/python
%define venv_pip %{venv_python} %{venv_bin}/pip install --find-links=%{wheel_dir} --no-index

# Tags
Name: st2client
Version: %{version}
Release: %{release}
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
  %{venv_cmd} %{venv_dir}
  %{venv_pip} .

  # RECORD files are used by wheels for checksum. They contain path names which
  # match the buildroot and must be removed or the package will fail to build.
  find %{buildroot} -name "RECORD" -exec rm -rf {} \;

  # Change the virtualenv path to the target installation direcotry.
  venvctrl-relocate --source=%{venv_dir} --destination=/%{venv_install_dir}
%prep
  rm -rf %{buildroot}
  mkdir -p %{buildroot}
%clean
  rm -rf %{buildroot}
