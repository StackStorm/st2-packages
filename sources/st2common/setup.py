# Forcing to use nothing, because dh-virtualenv requires working setup.py.
# This is not our case.

from setuptools import setup, find_packages

setup(
    name='st2common',
    version='0.4.0',
    description='',
    author='StackStorm',
    author_email='info@stackstorm.com',
    install_requires=[],
    test_suite='st2common',
    zip_safe=False,
    include_package_data=True,
    packages=find_packages(exclude=['ez_setup'])
)
