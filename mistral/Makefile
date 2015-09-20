WHEELDIR ?= /tmp/wheelhouse
COMPONENT := mistral
MISTRAL_RELEASE ?= 1
MISTRAL_VERSION ?= $(shell python -c "from pbr import version; print version.VersionInfo('mistral').version_string(),")

ifneq (,$(wildcard /etc/debian_version))
	DEBIAN := 1
	DESTDIR ?= $(CURDIR)/debian/mistral
else
	REDHAT := 1
endif

.PHONY: all install wheelhouse
all: install

install: wheelhouse changelog pre_install

post_install: bdist_wheel
	sed -i "s%/var/log/%/var/log/mistral/%" $(DESTDIR)/etc/mistral/*logging.conf

pre_install:
	install -D etc/wf_trace_logging.conf.sample $(DESTDIR)/etc/mistral/wf_trace_logging.conf

changelog: populate_version
ifeq ($(DEBIAN),1)
	debchange -v $(MISTRAL_VERSION)-$(MISTRAL_RELEASE) -M "automated build version: $(MISTRAL_VERSION)"
endif

populate_version: .stamp-populate_version
.stamp-populate_version:
	pip install $(shell cat requirements.txt | grep pbr)
	touch $@

wheelhouse: .stamp-wheelhouse
.stamp-wheelhouse: populate_version
	# Install wheels into shared location
	pip wheel --wheel-dir=$(WHEELDIR) -r requirements.txt
	touch $@

bdist_wheel: .stamp-bdist_wheel
.stamp-bdist_wheel: populate_version
	python setup.py bdist_wheel -d $(WHEELDIR)
	touch $@
