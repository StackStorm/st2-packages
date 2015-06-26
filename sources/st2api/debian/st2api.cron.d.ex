#
# Regular cron jobs for the st2api package
#
0 4	* * *	root	[ -x /usr/bin/st2api_maintenance ] && /usr/bin/st2api_maintenance
