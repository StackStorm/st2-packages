.PHONY: all pre_install install requirements wheelhouse

WHEELDIR ?= /tmp/wheelhouse
ST2_BUILD_VERSION ?= $(shell cat st2_version)

all: install

install: pre_install
	# Here're only files which are renamed, since the dh_install can't handle it.
	install -m644 ../conf/logrotate.conf $(DESTDIR)/etc/logrotate.d/st2.conf
	install -m644 ../conf/st2.prod.conf $(DESTDIR)/etc/st2/st2.conf
	# We don't want anything like below to be postinst
	sed -ir "/args\s*=\s*/s%logs%/var/log/st2%g" $(DESTDIR)/etc/st2auth/logging.conf

pre_install: wheelhouse
	debchange -v $(ST2_BUILD_VERSION) -M 'new version build'
	@echo "st2common" >> requirements.txt

# Borrow global version if there's no specific one (NOT .PHONY)
st2_version:
	install -m644 ../st2_version ./st2_version

requirements:
	python ../scripts/fixate-requirements.py -s in-requirements.txt -f ../fixed-requirements.txt

# Install wheels into shared location
wheelhouse: requirements st2_version
	pip wheel --wheel-dir=$(WHEELDIR) -r requirements.txt
