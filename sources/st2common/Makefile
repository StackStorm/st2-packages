.PHONY: all pre_install install requirements wheelhouse

WHEELDIR ?= /tmp/wheelhouse
ST2_BUILD_VERSION ?= $(shell cat st2_version)

all: install

# st2common can't be installed since it's not shiped as a standalone component.
install: ;

# Borrow global version if there's no specific one (NOT .PHONY)
st2_version:
	install -m644 ../st2_version ./st2_version

requirements:
	python ../scripts/fixate-requirements.py -s in-requirements.txt -f ../fixed-requirements.txt

# Install wheels into shared location
wheelhouse: requirements st2_version
	pip wheel --wheel-dir=$(WHEELDIR) -r requirements.txt
