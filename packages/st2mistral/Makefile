# Mind that that some of the vars are passed as ENV!
WHEELDIR ?= /tmp/wheelhouse
COMPONENT := st2mistral
MISTRAL_RELEASE ?= 1
MISTRAL_VERSION ?= $(shell python -c "from pbr import version; print version.VersionInfo('mistral').version_string(),")
# It's later than 0.11.1, so we have to use a later commit :(
PBR_GITURL := git+https://github.com/openstack-dev/pbr@d19459daa8616dd18fde016c2970ffc41ff4ccdd\#egg=pbr

# We use special additional requirements in our mistral bundle!
define INJECT_DEPS
gunicorn
git+https://github.com/StackStorm/st2mistral.git@$(GITREV)#egg=st2mistral
git+https://github.com/StackStorm/python-mistralclient.git@$(GITREV)#egg=python-mistralclient
$(PBR_GITURL)
endef
export INJECT_DEPS

ifneq (,$(wildcard /usr/share/python/st2python/bin/python))
	PATH := /usr/share/python/st2python/bin:$(PATH)
endif

ifneq (,$(wildcard /etc/debian_version))
	DEBIAN := 1
	DESTDIR ?= $(CURDIR)/debian/$(COMPONENT)
else
	REDHAT := 1
endif

all: install
.PHONY: all install changelog pre_install post_install

install: changelog wheelhouse pre_install

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
	sed -i "/^pbr.*/d" requirements.txt
	sed -i "s/setup_requires=\[.*\]/setup_requires=\['pbr'\]/" setup.py
	pip install $(PBR_GITURL)
	touch $@

wheelhouse: .stamp-wheelhouse
.stamp-wheelhouse: | populate_version inject-deps bdist_wheel
	# Install wheels into shared location
	pip wheel --wheel-dir=$(WHEELDIR) --find-links=$(WHEELDIR) -r requirements.txt
	touch $@

bdist_wheel: .stamp-bdist_wheel
.stamp-bdist_wheel: | populate_version
	python setup.py bdist_wheel -d $(WHEELDIR)
	touch $@

# We need to create bdist, before mangling requirements and running pip,
# otherwise proccess will fail.
inject-deps: .stamp-inject-deps
.stamp-inject-deps: | bdist_wheel
	echo "$$INJECT_DEPS" >> requirements.txt
	touch $@
