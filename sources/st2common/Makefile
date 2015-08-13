.PHONY: all install wheelhouse

WHEELDIR ?= /tmp/wheelhouse
ST2_COMPONENT := $(notdir $(CURDIR))
ST2PKG_RELEASE ?= 1
# ST2PKG_VERSION, can be passed via ENV, or it will be evaluated in st2version

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

pre_install:
	# Write temp files which will be processed by debhelpers
	install -D -m644 ../conf/st2.prod.conf $(DESTDIR)/etc/st2/st2.conf
	install -D -m644 ../conf/logrotate.conf $(DESTDIR)/etc/logrotate.d/st2

st2version:
	# Use common component version, by default
	$(eval SVER := $(shell python -c 'from $(ST2_COMPONENT) import __version__; print __version__,'))
	$(eval ST2PKG_VERSION ?= $(SVER))
	echo '>>>>>>>>>>>>>>>>>>>>>>>'
	echo $$ST2PKG_VERSION

requirements:
	python ../scripts/fixate-requirements.py -s in-requirements.txt -f ../fixed-requirements.txt

changelog: st2version
ifeq ($(DEBIAN),1)
	debchange -v $(ST2PKG_VERSION) -M "automated build version: $(ST2PKG_VERSION)"
endif

wheelhouse: .stamp-wheelhouse
.stamp-wheelhouse: st2version requirements
	# Install wheels into shared location
	pip wheel --wheel-dir=$(WHEELDIR) -r requirements.txt
	touch $@

bdist_wheel: .stamp-bdist_wheel
.stamp-bdist_wheel:
	# All other components depend on st2common, so we create st2common
	# in the shared WHEELHOUSE directory.
	python setup.py bdist_wheel
	touch $@
