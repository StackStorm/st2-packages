#!/usr/bin/env python

import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SCRIPTS_PATH = os.path.abspath(os.path.join(BASE_DIR, '../scripts'))

COMMON_INCLUDE_PATH = os.path.join(SCRIPTS_PATH, 'includes/common.sh')
RHEL_INCLUDE_PATH = os.path.join(SCRIPTS_PATH, 'includes/rhel.sh')

SCRIPT_FILES = [
    'st2bootstrap-deb.sh',
    'st2bootstrap-el6.sh',
    'st2bootstrap-el7.sh',
    'st2bootstrap-el8.sh'
]

HEADER_WARNING = """
#!/usr/bin/env bash
# NOTE: This file is automatically generated by the tools/generate_final_installer_scripts.py
# script using the template file and common include files in scripts/includes/*.sh.
#
# DO NOT EDIT MANUALLY.
#
# Please edit corresponding template file and include files.
""".strip()


def main():
    with open(COMMON_INCLUDE_PATH, 'r') as fp:
        common_script_content = fp.read()

    with open(RHEL_INCLUDE_PATH, 'r') as fp:
        rhel_common_script_content = fp.read()

    for script_filename in SCRIPT_FILES:
        script_file_path = os.path.join(SCRIPTS_PATH, script_filename)
        template_file_path = script_file_path.replace('.sh', '.template.sh')

        print('Generating script file "%s" -> "%s"' % (template_file_path, script_file_path))

        with open(template_file_path, 'r') as fp:
            template_content = fp.read()

        result = ''
        result += HEADER_WARNING
        result += '\n\n'
        result += template_content

        # Add in content from includes/ files
        result = result.replace('# include:includes/common.sh', common_script_content)
        result = result.replace('# include:includes/rhel.sh', rhel_common_script_content)

        with open(script_file_path, 'w') as fp:
            fp.write(result)

        print('File "%s" has been generated.' % (script_file_path))


if __name__ == '__main__':
    main()
