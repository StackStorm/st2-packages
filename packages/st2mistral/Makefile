# Mind that that some of the vars are passed as ENV!
WHEELDIR ?= /tmp/wheelhouse
COMPONENT := st2mistral
MISTRAL_RELEASE ?= 1
MISTRAL_VERSION ?= $(shell python -c "from pbr import version; print version.VersionInfo('mistral').version_string(),")
# It's later than 0.11.1, so we have to use a later commit :(
PBR_GITURL := git+https://github.com/openstack-dev/pbr@d19459daa8616dd18fde016c2970ffc41ff4ccdd\#egg=pbr

# We use special additional requirements in our mistral bundle!
define INJECT_DEPS
git+https://github.com/StackStorm/st2mistral.git@$(GITREV)#egg=st2mistral
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
	install -D conf/policy.json $(DESTDIR)/etc/mistral/policy.json
	install -D etc/logging.conf.sample $(DESTDIR)/etc/mistral/logging.conf
	install -m644 conf/logrotate.conf $(DESTDIR)/etc/logrotate.d/mistral
	install -D etc/wf_trace_logging.conf.sample $(DESTDIR)/etc/mistral/wf_trace_logging.conf
	install -D -m644 conf/helpers-sysvinit $(DESTDIR)/opt/stackstorm/mistral/share/sysvinit/helpers
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
	pip install $(PBR_GITURL) || \
		pip install $(PBR_GITURL)
	touch $@

wheelhouse: .stamp-wheelhouse
.stamp-wheelhouse: | populate_version inject-deps bdist_wheel
	# Install wheels into shared location
	pip wheel --wheel-dir=$(WHEELDIR) --find-links=$(WHEELDIR) -r requirements.txt || \
		pip wheel --wheel-dir=$(WHEELDIR) --find-links=$(WHEELDIR) -r requirements.txt
	touch $@

bdist_wheel: .stamp-bdist_wheel
.stamp-bdist_wheel: | populate_version
	# python setup.py bdist_wheel -d $(WHEELDIR)
	pip wheel --wheel-dir=$(WHEELDIR) --find-links=$(WHEELDIR) -r requirements.txt || \
		pip wheel --wheel-dir=$(WHEELDIR) --find-links=$(WHEELDIR) -r requirements.txt
	touch $@

# We need to create bdist, before mangling requirements and running pip,
# otherwise proccess will fail.
inject-deps: .stamp-inject-deps
.stamp-inject-deps: | bdist_wheel
	echo "$$INJECT_DEPS" >> requirements.txt
	grep -q 'gunicorn' requirements.txt || echo "gunicorn" >> requirements.txt
	grep -q 'openstacksdk' requirements.txt || echo "openstacksdk<0.21.0" >> requirements.txt
	grep -q 'psycopg2' requirements.txt || echo "psycopg2>=2.6.2,<2.7.0" >> requirements.txt
	grep -q 'pika' requirements.txt || echo "pika<0.11,>=0.9" >> requirements.txt
	grep -q 'python-memcached' requirements.txt || echo "python-memcached" >> requirements.txt
	sed -i "s/^oslo.messaging.*/oslo.messaging==5.24.2/g" requirements.txt
	sed -i "s/^Babel.*/Babel>=2.3.4,!=2.4.0 # BSD/g" requirements.txt

ifeq (,$(findstring dev,$(MISTRAL_VERSION)))
	sed -i "s/^python-mistralclient.*/git+https:\/\/github.com\/StackStorm\/python-mistralclient.git@st2-$(MISTRAL_VERSION)\#egg=python-mistralclient/g" requirements.txt
endif

	touch $@
