#
# Regular cron jobs for the st2client package
#
0 4	* * *	root	[ -x /usr/bin/st2client_maintenance ] && /usr/bin/st2client_maintenance
