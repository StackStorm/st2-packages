WHEELDIR ?= /tmp/wheelhouse
ST2_COMPONENT := $(notdir $(CURDIR))
ST2PKG_RELEASE ?= 1
# hardcode it for now since st2mistral doesn't have it's version
ST2PKG_VERSION = 0.1.0

ifneq (,$(wildcard /usr/share/python/st2python/bin/python))
	PATH := /usr/share/python/st2python/bin:$(PATH)
endif

ifneq (,$(wildcard /etc/debian_version))
	DEBIAN := 1
	DESTDIR ?= $(CURDIR)/debian/$(ST2_COMPONENT)
else
	REDHAT := 1
endif

.PHONY: all install wheelhouse
all: install

install: changelog bdist_wheel copy_wheel

changelog:
ifeq ($(DEBIAN),1)
	debchange -v $(ST2PKG_VERSION)-$(ST2PKG_RELEASE) -M "automated build version: $(ST2PKG_VERSION)"
endif

wheelhouse:
	# we don't really populate package dependencies, since we just build
	# the wheel which will be bundled inside st2mistral package

bdist_wheel: .stamp-bdist_wheel
.stamp-bdist_wheel:
	python setup.py bdist_wheel -d $(WHEELDIR)
	touch $@

copy_wheel:
	install -D -m644 $(WHEELDIR)/st2mistral*.whl $(DESTDIR)/usr/share/st2mistral
