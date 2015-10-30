WHEELDIR ?= /tmp/wheelhouse
ST2_COMPONENT := $(notdir $(CURDIR))
ST2PKG_RELEASE ?= 1
ST2PKG_VERSION ?= $(shell python -c "from $(ST2_COMPONENT) import __version__; print __version__,")

ifneq (,$(wildcard /etc/debian_version))
	DEBIAN := 1
	DESTDIR ?= $(CURDIR)/debian/$(ST2_COMPONENT)
else
	REDHAT := 1
endif

.PHONY: all install wheelhouse
all: install

install: wheelhouse changelog

post_install:
	# post_install is triggered debian/rules file, don't call it from install target!
	# We don't want anything like below to be postinst
	install -D -m644 ../conf/st2.package.conf $(DESTDIR)/etc/st2/st2.conf
	install -D -m644 ../conf/logrotate.conf $(DESTDIR)/etc/logrotate.d/st2
	install ../st2actions/conf/logging.conf $(DESTDIR)/etc/st2/logging.actionrunner.conf
	install ../st2actions/conf/syslog.conf $(DESTDIR)/etc/st2/syslog.actionrunner.conf
	install ../st2api/conf/logging.conf $(DESTDIR)/etc/st2/logging.api.conf
	install ../st2api/conf/syslog.conf $(DESTDIR)/etc/st2/syslog.api.conf
	install ../st2auth/conf/logging.conf $(DESTDIR)/etc/st2/logging.auth.conf
	install ../st2auth/conf/syslog.conf $(DESTDIR)/etc/st2/syslog.auth.conf
	sed -i -r "/args\s*=\s*/s%logs%/var/log/st2%g" $(DESTDIR)/etc/st2/logging.*conf

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
	touch $@
