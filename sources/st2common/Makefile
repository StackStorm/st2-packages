.PHONY: all install wheelhouse

WHEELDIR ?= /tmp/wheelhouse
ST2_COMPONENT := $(notdir $(CURDIR))
ST2PKG_RELEASE ?= 1
ST2PKG_VERSION ?= 0.1.0

ifneq (,$(wildcard /etc/debian_version))
	DEBIAN := 1
	DESTDIR ?= $(CURDIR)/debian/$(ST2_COMPONENT)
else
	REDHAT := 1
	RPM_SPECS_DIR := $(HOME)/rpmbuild/SPECS
	RPM_SOURCES_DIR := $(HOME)/rpmbuild/SOURCES
endif


all: install

install: wheelhouse changelog pre_install bdist_wheel

post_install: ;

pre_install:
	# Write temp files which will be processed by debhelpers
	install -D -m644 ../conf/st2.package.conf $(DESTDIR)/etc/st2/st2.conf
	install -D -m644 ../conf/logrotate.conf $(DESTDIR)/etc/logrotate.d/st2

populate_version: .stamp-populate_version
.stamp-populate_version:
	# populate version should be run before any pip/setup.py works
	sh ../scripts/populate-version.sh
	touch $@

requirements:
	python ../scripts/fixate-requirements.py -s in-requirements.txt -f ../fixed-requirements.txt

changelog: populate_version
ifeq ($(DEBIAN),1)
	debchange -v $(ST2PKG_VERSION) -M "automated build version: $(ST2PKG_VERSION)"
endif

wheelhouse: .stamp-wheelhouse
.stamp-wheelhouse: populate_version requirements
	# Install wheels into shared location
	pip wheel --wheel-dir=$(WHEELDIR) -r requirements.txt
	touch $@

bdist_wheel: .stamp-bdist_wheel
.stamp-bdist_wheel: populate_version
	# All other components depend on st2common, so we create st2common
	# in the shared WHEELHOUSE directory.
	python setup.py bdist_wheel -d $(WHEELDIR)
	touch $@
