#!/bin/bash
# Wheelhouse script is run at dependencies:pre stage, thus
# it's invoked after cache restore.
set -e

# Make ubuntu's .cache/pip owned by root
mkdir -p ~/.cache/pip && sudo chown -R root.root ~/.cache/pip
mkdir -p ~/wheelhouse && sudo chown -R root.root ~/wheelhouse
