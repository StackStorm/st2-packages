%define package st2client
%include ../rpmspec/package_top.spec

Summary: St2Client - StackStorm CLI utility
Requires: st2common = %{version}-%{release}

%description
  <insert long description, indented with spaces>

%install
  %default_install
  %pip_install_venv
  make post_install DESTDIR=%{?buildroot}

%prep
  rm -rf %{buildroot}
  mkdir -p %{buildroot}

%clean
  rm -rf %{buildroot}

%files
  %{_bindir}/*
  %{_datadir}/python/%{name}
