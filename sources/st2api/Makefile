.PHONY: all install wheelhouse

WHEELDIR ?= /tmp/wheelhouse
ST2_BUILD_VERSION ?= $(shell cat st2_version)
ST2_COMPONENT := $(notdir $(CURDIR))

ifneq (,$(wildcard /etc/debian_version))
	DESTDIR ?= $(CURDIR)/debian/$(ST2_COMPONENT)
endif


all: install

install: wheelhouse changelog

post_install:
	# post_install is triggered from rules, don't call it from install target!
	# We don't want anything like below to be postinst
	sed -i -r "/args\s*=\s*/s%logs%/var/log/st2%g" $(DESTDIR)/etc/st2api/logging.conf

st2_version:
	# Use top version if none is available under ./
	install -m644 ../st2_version ./st2_version

requirements:
	python ../scripts/fixate-requirements.py -s in-requirements.txt -f ../fixed-requirements.txt

changelog: st2_version wheelhouse
	# Add debian changelog entry for new automatic new version
	debchange -v $(ST2_BUILD_VERSION) -M 'new version build'
	# We can modify requirements ONLY AFTER wheelhouse has been built
	@echo "st2common" >> requirements.txt

wheelhouse: .stamp-wheelhouse
.stamp-wheelhouse: st2_version requirements
	# Install wheels into shared location
	pip wheel --wheel-dir=$(WHEELDIR) -r requirements.txt
	touch $@
