#!/usr/bin/env python

import argparse
import glob
import os
import sys
import json
import re
from itertools import islice

DISTROS = (os.environ.get('DISTROS') or sys.exit('DISTROS env variable is required!')).split(' ')
CIRCLE_NODE_TOTAL = int(os.environ.get('CIRCLE_NODE_TOTAL')) or sys.exit('CIRCLE_NODE_TOTAL env variable is required!')


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
            'doc': 'https://circleci.com/docs/environment-variables',
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


class BasePackageParse(object):
    """
    Base class for Package name parsers
    """

    def __init__(self, package_file):
        self.package = os.path.basename(package_file)

        match = self.PATTERN.match(self.package)
        if not match:
            raise ValueError("'{0}' naming doesn't looks like package".format(self.package))

        self.name = match.group('name')
        self.version = match.group('version')
        self.revision = match.group('revision')
        self.architecture = match.group('architecture')


class DebParse(BasePackageParse):
    """
    Parse metadata from .deb file name like: version number, revision number, architecture.
    Ex: st2api_1.2dev-20_amd64.deb
    """
    PATTERN = re.compile('^(?P<name>[^\/\n_]*)_(?P<version>[^_-]*)-(?P<revision>[^_-]*)_(?P<architecture>[^_]*)\.deb$')


class RpmParse(BasePackageParse):
    """
    Parse metadata from .deb file name like: version number, revision number, architecture.
    Ex: st2api-1.2dev-20.x86_64.rpm
    """
    PATTERN = re.compile('^(?P<name>[^\/]*)-(?P<version>[^-]*)-(?P<revision>[^-]*)\.(?P<architecture>[^-]*)\.rpm$')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Send Web Hook with build results to StackStorm")
    parser.add_argument('dir', help='directory tree with created packages')
    args = parser.parse_args()

    if int(env('DEPLOY_PACKAGES')):
        for distro in islice(DISTROS, CIRCLE_NODE_TOTAL):
            try:
                filename = (glob.glob(os.path.join(args.dir, distro, 'st2*.deb')) + glob.glob(os.path.join(args.dir, distro, 'st2*.rpm')))[0]
                if filename.endswith('.deb'):
                    package = DebParse(filename)
                elif filename.endswith('.rpm'):
                    package = RpmParse(filename)

                Payload.data['packages'].append({
                    'distro': distro,
                    'version': package.version,
                    'revision': package.revision
                })
            except IndexError:
                Payload.data['success'] = False
                Payload.data['reason'].append("CircleCI build produced no packages for '{0}'".format(distro))

    payload_file = os.path.abspath(os.path.join(args.dir, 'payload.json'))
    with open(payload_file, 'w') as f:
        f.write(json.dumps(Payload.data))

    print 'Build metadata will be available via URL:'
    print 'https://circle-artifacts.com/gh/{0}/{1}/{2}/artifacts/0{3}'.format(
        os.environ.get('CIRCLE_PR_USERNAME') or env('CIRCLE_PROJECT_USERNAME'),
        os.environ.get('CIRCLE_PR_REPONAME') or env('CIRCLE_PROJECT_REPONAME'),
        env('CIRCLE_BUILD_NUM'),
        payload_file
    )
    print ""
    print json.dumps(Payload.data)
