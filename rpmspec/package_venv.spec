%{!?venv_name: %define venv_name %{package}}
%define div_links bin/st2-bootstrap-rmq bin/st2-register-content
%define wheel_dir %(echo ${WHEELDIR:-/tmp/wheelhouse})

# virtualenv macroses
%define venv_install_dir opt/stackstorm/%{venv_name}
%define venv_dir %{buildroot}/%{venv_install_dir}
%define venv_bin %{venv_dir}/bin

%if 0%{?rhel} == 8
%define venv_python %{venv_bin}/python3
%define pin_pip %{venv_python} %{venv_bin}/pip install pip==19.1.1
%define install_crypto %{venv_python} %{venv_bin}/pip install cryptography==2.8 --no-binary cryptography
%define install_venvctrl python3 -m pip install venvctrl
%else
%define venv_python %{venv_bin}/python
%define pin_pip %{nil}
%define install_crypto %{nil}
%define install_venvctrl %{nil}
%endif

%define venv_pip %{venv_python} %{venv_bin}/pip install --find-links=%{wheel_dir} --no-index

# Change the virtualenv path to the target installation directory.
#   - Install dependencies
#   - Install package itself

# EL8 requires crypto built locally and venvctrl available outside of venv
%define pip_install_venv \
    virtualenv --no-download %{venv_dir} \
    %{pin_pip} \
    %{install_crypto} \
    %{venv_pip} -r requirements.txt \
    %{venv_pip} . \
    %{install_venvctrl} \
    venvctrl-relocate --source=%{venv_dir} --destination=/%{venv_install_dir} \
%{nil}
