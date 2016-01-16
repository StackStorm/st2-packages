%define package st2client
%include ../rpmspec/st2pkg_toptags.spec

Summary: St2Client - StackStorm CLI utility
Requires: st2common = %{version}-%{release}

%description
  <insert long description, indented with spaces>

%install
  %default_install
  %pip_install_venv
  make post_install DESTDIR=%{?buildroot}
  # clean up absolute path in record file, so that /usr/bin/check-buildroot doesn't fail
  find /root/rpmbuild/BUILDROOT/%{package}* -name RECORD -exec sed -i '/\/root\/rpmbuild.*$/d' '{}' ';'

%prep
  rm -rf %{buildroot}
  mkdir -p %{buildroot}

%clean
  rm -rf %{buildroot}

%files
  %{_bindir}/*
  %{_datadir}/python/%{name}
