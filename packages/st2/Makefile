WHEELDIR ?= /tmp/wheelhouse
ST2_COMPONENT := $(notdir $(CURDIR))
ST2PKG_RELEASE ?= 1
ST2PKG_VERSION ?= $(shell python -c "from $(ST2_COMPONENT) import __version__; print __version__,")
CHANGELOG_COMMENT ?= "automated build, version: $(ST2PKG_VERSION)"

ifneq (,$(wildcard /usr/share/python/st2python/bin/python))
	PATH := /usr/share/python/st2python/bin:$(PATH)
endif

ifneq (,$(wildcard /etc/debian_version))
	DEBIAN := 1
	#DEB_EPOCH := $(shell echo $(ST2PKG_VERSION) | grep -q dev || echo '1')
else
	REDHAT := 1
endif

# Only useful for debian builds
ifeq ($(DEB_EPOCH),)
	DEB_DISTRO := unstable
else
	DEB_DISTRO := $(shell lsb_release -cs)
endif

.PHONY: all install wheelhouse
all: install

install: wheelhouse changelog

post_install:
	# post_install is triggered from debian/rules file.
	# Don't call it from makefile install target!
	install -m640 /dev/null $(DESTDIR)/etc/st2/htpasswd
	install -m644 ../conf/st2.package.conf $(DESTDIR)/etc/st2/st2.conf
	install -m644 ../conf/logrotate.conf $(DESTDIR)/etc/logrotate.d/st2
	install -m644 ../st2actions/conf/logging.conf $(DESTDIR)/etc/st2/logging.actionrunner.conf
	install -m644 ../st2actions/conf/syslog.conf $(DESTDIR)/etc/st2/syslog.actionrunner.conf
	install -m644 ../st2api/conf/logging.conf $(DESTDIR)/etc/st2/logging.api.conf
	install -m644 ../st2api/conf/syslog.conf $(DESTDIR)/etc/st2/syslog.api.conf
	install -m644 ../st2stream/conf/logging.conf $(DESTDIR)/etc/st2/logging.stream.conf
	install -m644 ../st2stream/conf/syslog.conf $(DESTDIR)/etc/st2/syslog.stream.conf
	install -m644 ../st2auth/conf/logging.conf $(DESTDIR)/etc/st2/logging.auth.conf
	install -m644 ../st2auth/conf/syslog.conf $(DESTDIR)/etc/st2/syslog.auth.conf
	install -m755 bin/runners.sh $(DESTDIR)/opt/stackstorm/st2/bin/runners.sh
	sed -i -r "/args\s*=\s*/s%logs%/var/log/st2%g" $(DESTDIR)/etc/st2/logging.*conf
	sed -i "/\[logger_root\]/,/\[.*\]\|\s*$$/ {s/level=DEBUG/level=INFO/}" $(DESTDIR)/etc/st2/logging.*conf
	sed -i "/\[logger_root\]/,/\[.*\]\|\s*$$/ {s/level=DEBUG/level=INFO/}" $(DESTDIR)/etc/st2/syslog.*conf
ifeq ($(REDHAT),1)
	if [ `/root/scripts/platform_major_version.py` = 7 ]; then sed -i -r 's/virtualenv_opts\s*=.*/virtualenv_opts =/' $(DESTDIR)/etc/st2/st2.conf; fi
endif

populate_version: .stamp-populate_version
.stamp-populate_version:
	# populate version should be run before any pip/setup.py works
	sh ../scripts/populate-version.sh
	touch $@

requirements:
	python ../scripts/fixate-requirements.py -s ../st2*/in-requirements.txt -f ../fixed-requirements.txt
	cat requirements.txt

changelog: populate_version
ifeq ($(DEBIAN),1)
	[ -z "$(DEB_EPOCH)" ] && _epoch="" || _epoch="$(DEB_EPOCH):"; \
		dch -m --force-distribution -v$${_epoch}$(ST2PKG_VERSION)-$(ST2PKG_RELEASE) -D$(DEB_DISTRO) $(CHANGELOG_COMMENT)
endif

wheelhouse: .stamp-wheelhouse
.stamp-wheelhouse: | populate_version requirements inject-deps
	cat requirements.txt
	pip wheel --wheel-dir=$(WHEELDIR) --find-links=$(WHEELDIR) -r requirements.txt
	touch $@

# Note: We want to dynamically inject "st2client" dependency. This way we can
# pin it to the version we build so the requirement is satisfied by locally
# built wheel and not version from PyPi
inject-deps: .stamp-inject-deps
.stamp-inject-deps:
	# Note: We dynamically obtain the version, this is required because dev
	# build versions don't store correct version identifier in __init__.py
	# and we need setup.py to normalize iz
	$(eval $ST2PKG_NORMALIZED_VERSION :=$(shell python ../st2common/setup.py --version))
	echo "st2client==$($ST2PKG_NORMALIZED_VERSION)" >> requirements.txt
	touch $@
