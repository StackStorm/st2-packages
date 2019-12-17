WHEELDIR ?= /tmp/wheelhouse
ST2_COMPONENT := $(notdir $(CURDIR))
ST2PKG_RELEASE ?= 1
ST2PKG_VERSION ?= $(shell python -c "from $(ST2_COMPONENT) import __version__; print __version__,")

ifneq (,$(wildcard /etc/debian_version))
	DEBIAN := 1
	DEB_DISTRO := $(shell lsb_release -cs)
	DESTDIR ?= $(CURDIR)/debian/$(ST2_COMPONENT)
else ifeq (,$(wildcard /etc/centos-release))
   EL_DISTRO:=centos
   EL_VERSION:=$(shell cat /etc/centos-release | awk 'NF>1{print $4}' | cut -d. -f1)
else ifeq (,$(wildcard /etc/redhat-release))
   EL_DISTRO:=redhat
   EL_VERSION:=$(shell shell cat /etc/redhat-release | awk 'NF>1{print $4}' | cut -d. -f1)
else
	REDHAT := 1
	DEB_DISTRO := unstable
endif

ifeq ($(DEB_DISTRO),bionic)
	PYTHON_BINARY := /usr/bin/python3
	PIP_BINARY := /usr/bin/pip3
else ifeq ($(EL_VERSION),8)
    PYTHON_BINARY := /usr/bin/python3
    PIP_BINARY := /usr/bin/pip3
else ifneq (,$(wildcard /usr/share/python/st2python/bin/python))
	PATH := /usr/share/python/st2python/bin:$(PATH)
	PYTHON_BINARY := /usr/share/python/st2python/bin/python
	PIP_BINARY := pip
else
	PYTHON_BINARY := python
	PIP_BINARY := pip
endif

# Note: We dynamically obtain the version, this is required because dev
# build versions don't store correct version identifier in __init__.py
# and we need setup.py to normalize it (e.g. 1.4dev -> 1.4.dev0)
ST2PKG_NORMALIZED_VERSION ?= $(shell $(PYTHON_BINARY) setup.py --version || echo "failed_to_retrieve_version")

.PHONY: info
info:
	@echo "DEBIAN=$(DEBIAN)"
	@echo "REDHAT=$(REDHAT)"
	@echo "DEB_DISTRO=$(DEB_DISTRO)"
	@echo "PYTHON_BINARY=$(PYTHON_BINARY)"
	@echo "PIP_BINARY=$(PIP_BINARY)"

.PHONY: populate_version requirements wheelhouse bdist_wheel
all: info populate_version requirements bdist_wheel

populate_version: .stamp-populate_version
.stamp-populate_version:
	# populate version should be run before any pip/setup.py works
	sh ../scripts/populate-version.sh
	touch $@

requirements: .stamp-requirements
.stamp-requirements:
# Don't include Mistral runner on Bionic
ifeq ($(DEB_DISTRO),bionic)
	$(PYTHON_BINARY) ../scripts/fixate-requirements.py --skip=stackstorm-runner-mistral-v2,python-mistralclient -s in-requirements.txt -f ../fixed-requirements.txt
else ifeq ($(EL_VERSION),8)
	$(PYTHON_BINARY) ../scripts/fixate-requirements.py --skip=stackstorm-runner-mistral-v2,python-mistralclient -s in-requirements.txt -f ../fixed-requirements.txt
else
	$(PYTHON_BINARY) ../scripts/fixate-requirements.py -s in-requirements.txt -f ../fixed-requirements.txt
endif
	cat requirements.txt

wheelhouse: .stamp-wheelhouse
.stamp-wheelhouse: | populate_version requirements
	# Install wheels into shared location
	cat requirements.txt
	$(PIP_BINARY) wheel --wheel-dir=$(WHEELDIR) --find-links=$(WHEELDIR) -r requirements.txt || \
		$(PIP_BINARY) wheel --wheel-dir=$(WHEELDIR) --find-links=$(WHEELDIR) -r requirements.txt
	touch $@

bdist_wheel: .stamp-bdist_wheel
.stamp-bdist_wheel: | populate_version requirements inject-deps
	cat requirements.txt
	# pip2 uninstall -y wheel setuptools
	pip2 install wheel setuptools
	$(PYTHON_BINARY) setup.py bdist_wheel -d $(WHEELDIR) || \
		$(PYTHON_BINARY) setup.py bdist_wheel -d $(WHEELDIR)
	touch $@

# Note: We want to dynamically inject "st2client" dependency. This way we can
# pin it to the version we build so the requirement is satisfied by locally
# built wheel and not version from PyPi
inject-deps: .stamp-inject-deps
.stamp-inject-deps:
	echo "st2client==$(ST2PKG_NORMALIZED_VERSION)" >> requirements.txt
	touch $@
