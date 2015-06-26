#
# Regular cron jobs for the st2actions package
#
0 4	* * *	root	[ -x /usr/bin/st2actions_maintenance ] && /usr/bin/st2actions_maintenance
