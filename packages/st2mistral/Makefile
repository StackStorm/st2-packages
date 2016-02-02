WHEELDIR ?= /tmp/wheelhouse
COMPONENT := st2mistral
MISTRAL_RELEASE ?= 1
MISTRAL_VERSION ?= $(shell python -c "from pbr import version; print version.VersionInfo('mistral').version_string(),")

ifneq (,$(wildcard /usr/share/python/st2python/bin/python))
	PATH := /usr/share/python/st2python/bin:$(PATH)
endif

ifneq (,$(wildcard /etc/debian_version))
	DEBIAN := 1
	DESTDIR ?= $(CURDIR)/debian/$(COMPONENT)
else
	REDHAT := 1
endif

.PHONY: all install wheelhouse
all: install

install: wheelhouse changelog pre_install

post_install:
	# leave empty if no steps are required

pre_install:
	install -D etc/logging.conf.sample $(DESTDIR)/etc/mistral/logging.conf
	install -D etc/wf_trace_logging.conf.sample $(DESTDIR)/etc/mistral/wf_trace_logging.conf
	sed -i "s%/var/log/%/var/log/mistral/%" $(DESTDIR)/etc/mistral/*logging.conf
	sed -i "/\[logger_root\]/,/\[.*\]\|\s*$$/ {s/level=DEBUG/level=INFO/}" $(DESTDIR)/etc/mistral/*logging.conf

changelog: populate_version
ifeq ($(DEBIAN),1)
	debchange -v $(MISTRAL_VERSION)-$(MISTRAL_RELEASE) -M "automated build version: $(MISTRAL_VERSION)"
endif

populate_version: .stamp-populate_version
.stamp-populate_version:
	pip install $(shell cat requirements.txt | grep pbr)
	touch $@

wheelhouse: .stamp-wheelhouse
.stamp-wheelhouse: inject-deps populate_version
	# Install wheels into shared location
	pip wheel --wheel-dir=$(WHEELDIR) --find-links=$(WHEELDIR) -r requirements.txt
	touch $@

bdist_wheel: .stamp-bdist_wheel
.stamp-bdist_wheel: inject-deps populate_version
	python setup.py bdist_wheel -d $(WHEELDIR)
	touch $@

inject-deps: .inject-deps
.inject-deps:
	# We use gunicorn in our bundle!
	echo "gunicorn" >> requirements.txt
	touch $@
