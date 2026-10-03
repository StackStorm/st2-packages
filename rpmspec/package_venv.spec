%{!?venv_name: %define venv_name %{package}}
%define div_links bin/st2-bootstrap-rmq bin/st2-register-content
%define wheel_dir %(echo ${WHEELDIR:-/tmp/wheelhouse})

# virtualenv macros
%define venv_install_dir opt/stackstorm/%{venv_name}
%define venv_dir %{buildroot}/%{venv_install_dir}
%define venv_bin %{venv_dir}/bin

%define pybin python3
%define pipbin pip3
%define pipversion 26.2.1

# Forced to py3.11 instead of default py3.9 when building st2 v3.10 on rocky9
%if 0%{?rhel} == 9
%define pybin python3.11
%define pipbin pip3.11
%endif

%define venv_python %{venv_bin}/%{pybin}
# https://github.com/StackStorm/st2/wiki/Where-all-to-update-pip-and-or-virtualenv

%define pin_pip %{venv_python} %{venv_bin}/%{pipbin} install pip==%{pipversion}
%define install_venvctrl %{pybin} -m pip install venvctrl

%define install_crypto %{nil}

%define venv_pip %{venv_python} -m pip install --find-links=%{wheel_dir} --no-index

# Change the virtualenv path to the target installation directory.
#   - Install dependencies
#   - Install package itself

# EL8 requires crypto built locally.  venvctrl must be available outside of venv.
%define pip_install_venv \
    %{pybin} -m venv %{venv_dir} \
    %{pin_pip} \
    %{install_crypto} \
    %{venv_pip} -r requirements.txt \
    %{venv_pip} . \
    %{install_venvctrl} \
    venvctrl-relocate --source=%{venv_dir} --destination=/%{venv_install_dir} \
%{nil}
