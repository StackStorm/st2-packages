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

# Redefine and set some macroses to do proper bytecompile
# (/usr/lib/rpm/brp-python-bytecompile)
#
# We ship python into /usr/local, since we need updated on OSes < rhel7
%if "%([ -x /usr/local/bin/python ] && echo -n 1)" == "1"
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
%endif

# Set variable indicating that we use our python
%if "%(echo -n $ST2_PYTHON)" == "1"
  %global use_st2python 1
%else
  %global use_st2python 0
%endif
