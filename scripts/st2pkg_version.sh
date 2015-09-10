#!/bin/bash

debug "$BASH_SOURCE has been sourced!"

# We need to extract version or use environment var if it's given
make populate_version
version=$(python -c "from $1 import __version__; print __version__,")
export ST2PKG_VERSION=${ST2PKG_VERSION:-${version}}
