
{!?venv_name: %define venv_name %{package}}
%define div_links bin/st2-bootstrap-rmq bin/st2-register-content
%define wheel_dir %(echo ${WHEELDIR:-/tmp/wheelhouse})
%define venv_cmd virtualenv
%define venv_install_dir usr/share/python/%{venv_name}
%define venv_dir %{buildroot}/%{venv_install_dir}
%define venv_bin %{venv_dir}/bin
%define venv_python %{venv_bin}/python
%define venv_pip %{venv_python} %{venv_bin}/pip install --find-links=%{wheel_dir} --no-index

# Install a link to a common binary 
%define inst_venv_divertions \
  for file in %{div_links}; do \
    [ -L /usr/$file ] || ln -s /usr/share/python/%{package}/$file /usr/$file \
  done \
%{nil}

# Change/remove a link to common binary, if the package containing common binary is
# removed a link is changed to point to another package binary.
%define uninst_venv_divertions \
  for file in %{div_links}; do \
    [ -L /usr/$file ] && rm /usr/$file \
    div=$(find /usr/share/python/st2*/bin -name `basename $file` -executable -print -quit 2>/dev/null) \
    [ -z "$div" ] || ln -s $div /usr/$file \
  done \
%{nil}

# 1. RECORD files are used by wheels for checksum. They contain path names which
# match the buildroot and must be removed or the package will fail to build.
# 2. Change the virtualenv path to the target installation direcotry.
%define pip_install_venv \
  %{venv_cmd} %{venv_dir} \
  %{venv_pip} . \
  find %{buildroot} -name "RECORD" -exec rm -rf {} \\; \
  venvctrl-relocate --source=%{venv_dir} --destination=/%{venv_install_dir} \
%{nil}
