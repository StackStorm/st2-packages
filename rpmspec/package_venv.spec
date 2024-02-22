%{!?venv_name: %define venv_name %{package}}
%define div_links bin/st2-bootstrap-rmq bin/st2-register-content
%define wheel_dir %(echo ${WHEELDIR:-/tmp/wheelhouse})

# virtualenv macroses
%define venv_install_dir opt/stackstorm/%{venv_name}
%define venv_dir %{buildroot}/%{venv_install_dir}
%define venv_bin %{venv_dir}/bin

%if 0%{?rhel} == 8
%define python_binname python3.8
%define pip_binname pip3.8
%else
%define python_binname python3
%define pip_binname pip3
%endif

%if 0%{?rhel} == 9
%define virtualenv_binname virtualenv
%else
%define virtualenv_binname virtualenv-3
%endif


%define venv_python %{venv_bin}/%{python_binname}
# https://github.com/StackStorm/st2/wiki/Where-all-to-update-pip-and-or-virtualenv
%define pin_pip %{venv_python} %{venv_bin}/%{pip_binname} install pip==20.3.3
%define install_venvctrl %{python_binname} -m pip install venvctrl
%if 0%{?rhel} == 8
%define install_crypto %{venv_python} %{venv_bin}/pip3.8 install cryptography==2.8
%else
%define install_crypto %{nil}
%endif

%define venv_pip %{venv_python} %{venv_bin}/pip3 install --find-links=%{wheel_dir} --no-index

# Change the virtualenv path to the target installation directory.
#   - Install dependencies
#   - Install package itself

# EL8 requires crypto built locally and venvctrl available outside of venv
%define pip_install_venv \
    %{virtualenv_binname} -p %{python_binname} --no-download %{venv_dir} \
    %{pin_pip} \
    %{install_crypto} \
    %{venv_pip} --use-deprecated=legacy-resolver -r requirements.txt \
    %{venv_pip} --use-deprecated=legacy-resolver . \
    %{install_venvctrl} \
    venvctrl-relocate --source=%{venv_dir} --destination=/%{venv_install_dir} \
%{nil}
