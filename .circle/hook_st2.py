#!/usr/bin/env python

import argparse
import glob
import os
import sys
import json
import re
import requests
from itertools import islice

ST2_HOOK_URL = os.environ.get('ST2_HOOK_URL') or sys.exit('ST2_HOOK_URL env variable is required!')
ST2_API_KEY = os.environ.get('ST2_API_KEY') or sys.exit('ST2_API_KEY env variable is required!')
DISTROS = (os.environ.get('DISTROS') or sys.exit('DISTROS env variable is required!')).split(' ')
CIRCLE_NODE_TOTAL = int(os.environ.get('CIRCLE_NODE_TOTAL')) or sys.exit('CIRCLE_NODE_TOTAL env variable is required!')
requests.packages.urllib3.disable_warnings()


def env(var):
    """
    Shortcut to get ENV variable value
    :param var: Input environment variable name
    :type var: ``str``
    :return:
    :rtype: ``str``
    """
    return os.environ.get(var, '')


class Payload(object):
    """
    Representation of data to be send to ST2 via Web Hook
    """
    data = {
        'success': True,
        'reason': [],
        'circle': {
            'CIRCLE_PROJECT_USERNAME': env('CIRCLE_PROJECT_USERNAME'),
            'CIRCLE_PROJECT_REPONAME': env('CIRCLE_PROJECT_REPONAME'),
            'CIRCLE_BRANCH': env('CIRCLE_BRANCH'),
            'CIRCLE_SHA1': env('CIRCLE_SHA1'),
            'CIRCLE_COMPARE_URL': env('CIRCLE_COMPARE_URL'),
            'CIRCLE_BUILD_NUM': env('CIRCLE_BUILD_NUM'),
            'CIRCLE_PREVIOUS_BUILD_NUM': env('CIRCLE_PREVIOUS_BUILD_NUM'),
            'CI_PULL_REQUESTS': env('CI_PULL_REQUESTS'),
            'CI_PULL_REQUEST': env('CI_PULL_REQUEST'),
            'CIRCLE_USERNAME': env('CIRCLE_USERNAME'),
            'CIRCLE_PR_USERNAME': env('CIRCLE_PR_USERNAME'),
            'CIRCLE_PR_REPONAME': env('CIRCLE_PR_REPONAME'),
            'CIRCLE_PR_NUMBER': env('CIRCLE_PR_NUMBER'),
            'CIRCLE_NODE_TOTAL': env('CIRCLE_NODE_TOTAL'),
        },
        'build': {
            'ST2_GITURL': env('ST2_GITURL'),
            'ST2_GITREV': env('ST2_GITREV'),
            'DEPLOY_PACKAGES': env('DEPLOY_PACKAGES'),
            'DISTROS': env('DISTROS'),
            'NOTESTS': env('NOTESTS'),
        },
        'packages': [],
    }


class DebParse(object):
    """
    Parse metadata from .deb file name like: version number, revision number, architecture.
    """
    PATTERN = re.compile('^(?P<name>[^/\n_]*)_(?P<version>[^_-]*)-(?P<revision>[^_-]*)_(?P<architecture>[^_]*)\.deb$')

    def __init__(self, package_file):
        self.package = os.path.basename(package_file)

        match = self.PATTERN.match(self.package)
        if not match:
            raise ValueError("'{0}' naming doesn't looks like package".format(self.package))

        self.name = match.group('name')
        self.version = match.group('version')
        self.revision = match.group('revision')
        self.architecture = match.group('architecture')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Send Web Hook with build results to StackStorm")
    parser.add_argument('dir', help='directory tree with created packages')
    args = parser.parse_args()

    if int(env('DEPLOY_PACKAGES')):
        for distro in islice(DISTROS, CIRCLE_NODE_TOTAL):
            try:
                filename = glob.glob(os.path.join(args.dir, distro, 'st2api*.deb'))[0]
                deb = DebParse(filename)
                Payload.data['packages'].append({
                    'distro': distro,
                    'version': deb.version,
                    'revision': deb.revision
                })
            except IndexError:
                Payload.data['success'] = False
                Payload.data['reason'].append("CircleCI build produced no packages for '{0}'".format(distro))

    headers = {
        'Content-Type': 'application/json',
        'St2-Api-Key': ST2_API_KEY
    }
    response = requests.post(ST2_HOOK_URL, headers=headers, json=Payload.data, verify=False)
    if response.status_code != 202:
        raise Exception("Failed to hook ST2: {0}\n\n{1}".format(response.status_code, response.text))

    print 'OK: {0}\n\n{1}'.format(response.status_code, response.text)
