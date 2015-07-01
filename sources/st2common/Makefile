.PHONY: all install wheelhouse

WHEELDIR ?= /tmp/wheelhouse
# ST2PKG_BUILDVER it's evaluated in st2version, but can be overriden
ST2_COMPONENT := $(notdir $(CURDIR))

ifneq (,$(wildcard /etc/debian_version))
	DESTDIR ?= $(CURDIR)/debian/$(ST2_COMPONENT)
endif


all: install

install: wheelhouse changelog pre_install

pre_install:
	# Write temp files which will be processed by debhelpers
	install -D -m644 ../conf/st2.prod.conf $(DESTDIR)/etc/st2/st2.conf
	install -D -m644 ../conf/logrotate.conf $(DESTDIR)/etc/logrotate.d/st2

st2version:
	# Use common component version, by default
	$(eval SVER := $(shell python -c 'from $(ST2_COMPONENT) import __version__; print __version__,'))
	$(eval ST2PKG_BUILDVER ?= $(SVER))

requirements:
	python ../scripts/fixate-requirements.py -s in-requirements.txt -f ../fixed-requirements.txt

changelog: st2version
	# Add debian changelog entry for new automatic new version
	debchange -v $(ST2PKG_BUILDVER) -M 'new version build'

wheelhouse: .stamp-wheelhouse
.stamp-wheelhouse: st2version requirements
	# Install wheels into shared location
	pip wheel --wheel-dir=$(WHEELDIR) -r requirements.txt
	touch $@
