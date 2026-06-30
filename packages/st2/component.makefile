WHEELDIR ?= /tmp/wheelhouse
ST2_COMPONENT := $(notdir $(CURDIR))
ST2PKG_RELEASE ?= 1

ifneq (,$(wildcard /etc/debian_version))
	DEBIAN := 1
	DEB_DISTRO := $(shell lsb_release -cs)
	DESTDIR ?= $(CURDIR)/debian/$(ST2_COMPONENT)
else ifneq (,$(wildcard /etc/rocky-release))
	EL_DISTRO := rocky
	EL_VERSION := $(shell cat /etc/rocky-release | grep -oP '(?<= )[0-9]+(?=\.)')
	REDHAT := 1
else ifneq (,$(wildcard /etc/redhat-release))
	EL_DISTRO := redhat
	EL_VERSION := $(shell cat /etc/redhat-release | grep -oP '(?<= )[0-9]+(?=\.)')
	REDHAT := 1
else
	REDHAT := 1
	DEB_DISTRO := unstable
endif

PYTHON_VERSION ?= 3
PYTHON_BINARY := /usr/bin/python$(PYTHON_VERSION)
PIP_BINARY := /usr/bin/pip$(PYTHON_VERSION)
PYTHON_ALT_BINARY := python$(PYTHON_VERSION)
PIP_VERSION ?= 25.3

# Moved from top of file to handle when only py2 or py3 available
ST2PKG_VERSION ?= $(shell $(PYTHON_BINARY) -c "from $(ST2_COMPONENT) import __version__; print(__version__),")

.PHONY: ensure-python
ensure-python:
ifeq ($(DEBIAN),1)
	@if [ "$(PYTHON_VERSION)" != "3" ] && [ ! -x "$(PYTHON_BINARY)" ]; then \
		echo "Installing Python $(PYTHON_VERSION) on Debian/Ubuntu..."; \
		apt-get update && \
		apt-get install -y software-properties-common && \
		add-apt-repository -y ppa:deadsnakes/ppa && \
		apt-get update && \
		apt-get install -y python$(PYTHON_VERSION) python$(PYTHON_VERSION)-dev python$(PYTHON_VERSION)-venv; \
	fi
else ifeq ($(REDHAT),1)
	@if [ "$(PYTHON_VERSION)" != "3" ] && [ ! -x "$(PYTHON_BINARY)" ]; then \
		echo "Installing Python $(PYTHON_VERSION) on RHEL/Rocky..."; \
		yum install -y python$(PYTHON_VERSION) python$(PYTHON_VERSION)-devel 2>/dev/null || \
		dnf install -y python$(PYTHON_VERSION) python$(PYTHON_VERSION)-devel; \
	fi
endif

# Note: We dynamically obtain the version, this is required because dev
# build versions don't store correct version identifier in __init__.py
# and we need setup.py to normalize it (e.g. 1.4dev -> 1.4.dev0)
ST2PKG_NORMALIZED_VERSION ?= $(shell $(PYTHON_BINARY) setup.py --version || echo "failed_to_retrieve_version")

.PHONY: info
info: ensure-python
	@echo "DEBIAN=$(DEBIAN)"
	@echo "REDHAT=$(REDHAT)"
	@echo "DEB_DISTRO=$(DEB_DISTRO)"
	@echo "PYTHON_BINARY=$(PYTHON_BINARY)"
	@echo "PIP_BINARY=$(PIP_BINARY)"
	@echo "EL_VERSION=$(EL_VERSION)"
	@echo "EL_DISTRO=$(EL_DISTRO)"
	$(PIP_BINARY) --version

.PHONY: populate_version requirements wheelhouse bdist_wheel
all: ensure-python info populate_version requirements bdist_wheel

populate_version: .stamp-populate_version
.stamp-populate_version:
	# populate version should be run before any pip/setup.py works
	sh ../scripts/populate-version.sh
	touch $@

requirements: .stamp-requirements
.stamp-requirements:
	$(PYTHON_BINARY) ../scripts/fixate-requirements.py -s in-requirements.txt -f ../fixed-requirements.txt
	cat requirements.txt

wheelhouse: .stamp-wheelhouse
.stamp-wheelhouse: | populate_version requirements
	# Install wheels into shared location
	cat requirements.txt
	# Upgrade pip to specified version
	$(PIP_BINARY) install --upgrade pip==$(PIP_VERSION)
	# Try to install wheels 2x in case the first one fails
	$(PIP_BINARY) --use-deprecated=legacy-resolver wheel --wheel-dir=$(WHEELDIR) --find-links=$(WHEELDIR) -r requirements.txt || \
		$(PIP_BINARY) --use-deprecated=legacy-resolver wheel --wheel-dir=$(WHEELDIR) --find-links=$(WHEELDIR) -r requirements.txt
	touch $@

bdist_wheel: .stamp-bdist_wheel
.stamp-bdist_wheel: | populate_version requirements inject-deps
	cat requirements.txt
	# Upgrade pip to specified version
	$(PIP_BINARY) install --upgrade pip==$(PIP_VERSION)
# We need to install these python packages to handle rpmbuild 4.14 in EL8
ifeq ($(EL_VERSION),8)
	$(PIP_BINARY) install wheel setuptools virtualenv
	$(PIP_BINARY) install cryptography
endif
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
