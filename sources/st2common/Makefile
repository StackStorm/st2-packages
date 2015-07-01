.PHONY: all install wheelhouse

WHEELDIR ?= /tmp/wheelhouse
ST2_BUILD_VERSION ?= $(shell cat st2_version)
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

st2_version:
	# Use top version if none is available under ./
	install -m644 ../st2_version ./st2_version

requirements:
	python ../scripts/fixate-requirements.py -s in-requirements.txt -f ../fixed-requirements.txt

changelog: st2_version wheelhouse
	# Add debian changelog entry for new automatic new version
	debchange -v $(ST2_BUILD_VERSION) -M 'new version build'

wheelhouse: .stamp-wheelhouse
.stamp-wheelhouse: st2_version requirements
	# Install wheels into shared location
	pip wheel --wheel-dir=$(WHEELDIR) -r requirements.txt
	touch $@
