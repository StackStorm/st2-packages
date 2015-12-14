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
  %{debian_dirs} \
  %{debian_install} \
  %debian_links \
  %make_install \
%{nil}

# St2 package version parsing
%define st2_component %(echo $ST2_PACKAGES st2 bundle | grep -q %{package} && echo -n 1 || :)
%{?st2_component: %define st2pkg_version %(python -c "from %{package} import __version__; print __version__,")}

# Define use_systemd to know if we on a systemd system
%global use_systemd %{!?_unitdir:0}%{?_unitdir:1}

# Redefine and to drop python brp bytecompile
#
%define __os_install_post() \
    /usr/lib/rpm/redhat/brp-compress \
    %{!?__debug_package:/usr/lib/rpm/redhat/brp-strip %{__strip}} \
    /usr/lib/rpm/redhat/brp-strip-static-archive %{__strip} \
    /usr/lib/rpm/redhat/brp-strip-comment-note %{__strip} %{__objdump} \
%{nil}

# Set variable indicating that we use our python
%if "%(echo -n $ST2_PYTHON)" == "1"
  %global use_st2python 1
%else
  %global use_st2python 0
%endif

# Install systemd or sysv service into the package
#
%define service_install() \
  %if %{use_systemd} \
    for svc in %{?*}; do \
      install -D -p -m0644 %{SOURCE0}/rpm/$svc.service %{buildroot}%{_unitdir}/$svc.service \
    done \
  %else \
    for svc in %{?*}; do \
      install -D -p -m0755 %{SOURCE0}/rpm/$svc.init %{buildroot}%{_sysconfdir}/rc.d/init.d/$svc \
    done \
  %endif \
%{nil}

# Service post stage action
# enables used to enforce the policy, which seems to be disabled by default
#
%define service_post() \
  %if %{use_systemd} \
    %{expand: %systemd_post %%{?*}} \
    systemctl --no-reload enable %{?*} >/dev/null 2>&1 || : \
  %else \
    for svc in %{?*}; do \
      /sbin/chkconfig --add $svc || : \
    done \
  %endif \
%{nil}

# Service preun stage action
#
%define service_preun() \
  %if %{use_systemd} \
    %{expand: %systemd_preun %%{?*}} \
  %else \
    for svc in %{?*}; do \
      /sbin/service $svc stop &>/dev/null || : \
      /sbin/chkconfig --del $svc &>/dev/null || : \
    done \
  %endif \
%{nil}

# Service postun stage action
# ($1 > 1 on package upgrade)
#
%define service_postun() \
  %if %{use_systemd} \
    %{expand: %systemd_postun_with_restart %%{?*}} \
  %else \
    if [ $1 -ge 1 ]; then \
      for svc in %{?*}; do \
        /sbin/service $svc try-restart &>/dev/null || : \
      done \
    fi \
  %endif \
%{nil}
