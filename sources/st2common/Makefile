.PHONY: install debchange all

default-stamp: st2_version debchange
	touch default-stamp

st2_version:
	# Borrow global version if there's no specific one (NOT .PHONY)
	install -m644 ../st2_version ./st2_version

install:
	install -m644 ../conf/logrotate.conf $(DESTDIR)/etc/logrotate.d/st2.conf
	install -m644 ../conf/st2.prod.conf $(DESTDIR)/etc/st2/st2.conf
	# We don't do: install ../tools/*
	# Because this sort of hackery should NOT go to prod, and if someone
	# needs he can install it.

debchange:
	$(eval ST2_VER := $(shell cat st2_version))
	debchange -v $(ST2_VER) -M 'new version build'

all: default-stamp install
