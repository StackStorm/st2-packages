#
# Regular cron jobs for the st2auth package
#
0 4	* * *	root	[ -x /usr/bin/st2auth_maintenance ] && /usr/bin/st2auth_maintenance
