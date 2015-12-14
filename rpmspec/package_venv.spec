%{!?venv_name: %define venv_name %{package}}
%define div_links bin/st2-bootstrap-rmq bin/st2-register-content
%define wheel_dir %(echo ${WHEELDIR:-/tmp/wheelhouse})

# Use specific python, not distro's default but ours - st2python.
%if %{use_st2python}
  %define venv_cmd virtualenv -p /usr/share/python/st2python/bin/python
%else
  %define venv_cmd virtualenv
%endif

%define venv_install_dir usr/share/python/%{venv_name}
%define venv_dir %{buildroot}/%{venv_install_dir}
%define venv_bin %{venv_dir}/bin
%define venv_python %{venv_bin}/python
%define venv_pip %{venv_python} %{venv_bin}/pip install --find-links=%{wheel_dir}

# 1. RECORD files are used by wheels for checksum. They contain path names which
# match the buildroot and must be removed or the package will fail to build.
# 2. Change the virtualenv path to the target installation direcotry.
# 3. Install dependencies
# 4. Install package itself
%define pip_install_venv \
  %{venv_cmd} %{venv_dir} \
  %{venv_pip} -r requirements.txt \
  %{venv_pip} . \
  find %{buildroot} -name "RECORD" -exec rm -rf {} \\; \
  venvctrl-relocate --source=%{venv_dir} --destination=/%{venv_install_dir} \
%{nil}
