.DEFAULT_GOAL := empty

.PHONY: install
install:
	install -m644 ../conf/logrotate.conf $(DESTDIR)/etc/logrotate.d/st2.conf
	install -m644 ../conf/st2.prod.conf $(DESTDIR)/etc/st2/st2.conf
	# Don't need this sort of hackery, all that scripts and etc...
	# So we don't do: install ../tools/*

empty:
