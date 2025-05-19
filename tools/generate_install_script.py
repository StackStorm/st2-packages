#!/usr/bin/env python3
"""
Generate st2bootstrap install scripts based on a set of supported operating systems.

A bootstrap script is generated per operating system based on a central jinja template
that includes other templates based on information provided in the operating system
data file `generate_install_script.json`.
"""
import os
import json
from jinja2 import Environment, FileSystemLoader

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SCRIPTS_PATH = os.path.abspath(os.path.join(BASE_DIR, "../scripts"))
TEMPLATE_PATH = os.path.abspath(os.path.join(BASE_DIR, "../templates"))
TEMPLATE_FILE = "st2bootstrap.jinja"
DATA_FILE = os.path.abspath(os.path.join(BASE_DIR, "generate_install_script.json"))


def load_json(filename):
    """
    Load JSON from file and return the deserialised content.
    """
    with open(filename, "r", encoding="utf-8") as f:
        return json.load(f)


def fetch_template(template="st2bootstrap.jinja", template_dir="."):
    """
    Load Jinja template and return the template object.
    """
    file_loader = FileSystemLoader(template_dir)
    env = Environment(loader=file_loader)
    return env.get_template(template)


def render_document(template, data, filename, backup_file=False):
    """
    Given the template object and data, render the template and write to the filename.
    """
    if backup_file:
        if not os.path.exists(f"{filename}.bak") and os.path.exists(f"{filename}"):
            os.replace(f"{filename}", f"{filename}.bak")
    with open(filename, "w", encoding="utf-8") as f:
        f.write(template.render(data))


def main():
    """
    Entry point.
    """
    # $ID and $VERSION_ID are sourced from /etc/os-release
    # In the case where VERSION_ID contains major.minor id, it's possible
    # to list the key with only the major id and have any minor id match
    # against it to use the same template across a major version of the distribuion.
    # Adding a key with the required data will produce a bootstrap script
    # for the OS.
    data = load_json(DATA_FILE)

    for os_data in data:
        os_id = os_data["id"]
        os_version_id = os_data["version_id"]

        script_filename = os_data["script_filename"]
        script_abs_filename = os.path.join(SCRIPTS_PATH, script_filename)

        print(f"Generating script file '{script_filename}' for {os_id} {os_version_id}")
        template = fetch_template(TEMPLATE_FILE, TEMPLATE_PATH)
        render_document(template, os_data, script_abs_filename)


if __name__ == "__main__":
    main()
