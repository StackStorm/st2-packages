# !!! Following list of variables must be defined before this file is included.
#   - package

# Cat debian/package.dirs, set buildroot prefix and create directories.
%define debian_dirs cat debian/%{name}.dirs | grep -v '^\\s*#' | sed 's~^~%{buildroot}/~' | \
          while read dir_path; do \
            mkdir -p "${dir_path}" \
          done \
%{nil}

# Cat debian/package.links, set buildroot prefix and create symlinks.
%define debian_links cat debian/%{name}.links | grep -v '^\\s*#' | \
            sed -r -e 's~\\b~/~' -e 's~\\s+\\b~ %{buildroot}/~' | \
          while read link_rule; do \
            linkpath=$(echo "$link_rule" | cut -f2 -d' ') && [ -d $(dirname "$linkpath") ] || \
              mkdir -p $(dirname "$linkpath") && ln -s $link_rule \
          done \
%{nil}

# Cat debian/install, set buildroot prefix and copy files.
%define debian_install cat debian/install | grep -v '^\s*#' | sed -r 's~ +~ %{buildroot}/~' | \
          while read copy_rule; do \
            parent=$(echo "$copy_rule" | cut -f2 -d' ') \
            [ -d "$parent" ] || install -d "$parent" && cp -r $copy_rule \
          done \
%{nil}

# We hate duplication right :)?, so let's use debian files
%define default_install \
  %debian_dirs \
  %debian_install \
  %debian_links \
  %make_install \
%{nil}

## Clean up RECORD and some other files left by python, which may contain
#   absolute buildroot paths.
%define cleanup_python_abspath \
  find %{buildroot} -name RECORD -o -name '*.egg-link' -o -name '*.pth' | \
      xargs -I{} -n1 sed -i 's@%{buildroot}@@' {} \
%{nil}

# Define use_systemd to know if we on a systemd system
#
%if 0%{?_unitdir:1}
  %define use_systemd 1
%endif

## St2 package version parsing
#   if package name starts with st2 then it's st2 component.
#
%if %(PKG=%{package}; [ "${PKG##st2}" != "$PKG" ] && echo 1 || echo 0 ) == 1
%if 0%{?rhel} >= 8
  %define st2pkg_version %(python3 -c "from %{package} import __version__; print(__version__),")
%else
  %define st2pkg_version %(python -c "from %{package} import __version__; print(__version__),")
%endif  # if rhel8
%endif  # st2 package version parsing

# Redefine and to drop python brp bytecompile
#
%define __os_install_post() \
    /usr/lib/rpm/brp-compress \
    %{!?__debug_package:/usr/lib/rpm/brp-strip %{__strip}} \
    /usr/lib/rpm/brp-strip-static-archive %{__strip} \
    /usr/lib/rpm/brp-strip-comment-note %{__strip} %{__objdump} \
%{nil}

# Install systemd service into the package
#
%define service_install() \
  for svc in %{?*}; do \
    install -D -p -m0644 %{SOURCE0}/rpm/$svc.service %{buildroot}%{_unitdir}/$svc.service \
    [ -f %{SOURCE0}/rpm/$svc.socket ] && install -D -p -m0644 %{SOURCE0}/rpm/$svc.socket %{buildroot}%{_unitdir}/$svc.socket \
  done \
%{nil}

# Service post stage action
# enables used to enforce the policy, which seems to be disabled by default
#
%define service_post() \
  %{expand: %systemd_post %%{?*}} \
  systemctl --no-reload enable %{?*} >/dev/null 2>&1 || : \
%{nil}

# Service preun stage action
#
%define service_preun() \
  %{expand: %systemd_preun %%{?*}} \
%{nil}

# Service postun stage action
# ($1 > 1 on package upgrade)
#
%define service_postun() \
  %{expand: %systemd_postun_with_restart %%{?*}} \
%{nil}
