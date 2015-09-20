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
