.PHONY: all install wheelhouse

WHEELDIR ?= /tmp/wheelhouse
# ==!! ST2PKG_VERSION it's evaluated in st2version, but can be overriden
ST2_COMPONENT := $(notdir $(CURDIR))

ifneq (,$(wildcard /etc/debian_version))
	DESTDIR ?= $(CURDIR)/debian/$(ST2_COMPONENT)
endif


all: install

install: wheelhouse changelog

post_install: ;

st2version: install_py_version
	# Use common component version, by default
	$(eval SVER := $(shell python -c 'from $(ST2_COMPONENT) import __version__; print __version__,'))
	$(eval ST2PKG_VERSION ?= $(SVER))

install_py_version:
	# Install __init__.py of st2common (containging __version__) in case if
	# component doesn't file.
ifeq (,$(wildcard $(ST2_COMPONENT)/__init__.py))
	install -m644 ../st2common/st2common/__init__.py ./$(ST2_COMPONENT)/__init__.py
endif

requirements:
	python ../scripts/fixate-requirements.py -s in-requirements.txt -f ../fixed-requirements.txt

changelog: st2version
	# Add debian changelog entry for new automatic new version
	debchange -v $(ST2PKG_VERSION) -M 'new version build'

wheelhouse: .stamp-wheelhouse
.stamp-wheelhouse: st2version requirements
	# Install wheels into shared location
	pip wheel --wheel-dir=$(WHEELDIR) -r requirements.txt
	# We can modify requirements ONLY AFTER wheelhouse has been built
	@echo "st2common" >> requirements.txt
	touch $@
