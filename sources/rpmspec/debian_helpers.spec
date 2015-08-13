
%define debian_dirs cat debian/%{name}.dirs | grep -v '^\s*#' | sed 's~^~%{buildroot}/~' | \
          while read dir_path; do \
            mkdir -p "${dir_path}" \
          done

%define debian_install cat debian/install | grep -v '^\s*#' | sed -r 's~ +~ %{buildroot}/~' | \
          while read copy_rule; do \
            mkdir -p $(echo $copy_rule | cut -f2 -d' ') && cp -r $copy_rule \
          done
