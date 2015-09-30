
# Redifine and set some macroses to do proper bytecompile
# (/usr/lib/rpm/brp-python-bytecompile)
#
%define __python /usr/local/bin/python
%define __os_install_post() \
    /usr/lib/rpm/redhat/brp-compress \
    %{!?__debug_package:/usr/lib/rpm/redhat/brp-strip %{__strip}} \
    /usr/lib/rpm/redhat/brp-strip-static-archive %{__strip} \
    /usr/lib/rpm/redhat/brp-strip-comment-note %{__strip} %{__objdump} \
    /usr/lib/rpm/brp-python-bytecompile %{__python} \
    /usr/lib/rpm/redhat/brp-python-hardlink \
    %{!?__jar_repack:/usr/lib/rpm/redhat/brp-java-repack-jars} \
%{nil}

%global unicode ucs4

# ==================
# Top-level metadata
# ==================
Summary: An interpreted, interactive, object-oriented programming language
Name: st2python
Version: %(echo -n "${ST2_PYTHON_VERSION:-2.7.10}")
Release: %(echo -n "${ST2_PYTHON_RELEASE:-1}")
License: Python
Group: Development/Languages
Source: https://www.python.org/ftp/python/%{version}/Python-%{version}.tar.xz

%description
Python is an interpreted, interactive, object-oriented programming
language often compared to Tcl, Perl, Scheme or Java. Python includes
modules, classes, exceptions, very high level dynamic data types and
dynamic typing. Python supports interfaces to many system calls and
libraries, as well as to various windowing systems (X11, Motif, Tk,
Mac and MFC).

Programmers can write new built-in modules for Python in C or C++.
Python can be used as an extension language for applications that need
a programmable interface.

%prep
%setup -q -n Python-%{version}

%build
topdir=$(pwd)
./configure \
  --enable-ipv6 \
  --enable-unicode=%{unicode} \
  --prefix=/usr/share/python/st2python \
  --exec-prefix=/usr/share/python/st2python
  %{nil}

# Patch cgi.py to use absolute path, info inside the file.
sed -i '1s:/usr/local/bin/python:/usr/share/python/st2python/bin/python:' Lib/cgi.py
make

%install
topdir=$(pwd)
rm -rf %{buildroot}
mkdir -p %{buildroot}%{_prefix}
make install DESTDIR=%{buildroot}

# cleanout tests (some of them have python3 syntax)
rm -rf %{buildroot}%{_datadir}/python/st2python/lib/python2.7/test
rm -rf %{buildroot}%{_datadir}/python/st2python/lib/python2.7/lib2to3/tests

%files
  %{_datadir}/python/st2python
