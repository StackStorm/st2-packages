#
# Regular cron jobs for the st2reactor package
#
0 4	* * *	root	[ -x /usr/bin/st2reactor_maintenance ] && /usr/bin/st2reactor_maintenance
