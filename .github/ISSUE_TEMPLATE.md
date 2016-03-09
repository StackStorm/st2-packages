If you find an issue in packages, please file an issue and we'll have a look as soon as we can.
In order to expedite the process, it would be helpful to follow this checklist and provide
relevant information.

  * [ ] Operating system: `uname -a`, `./etc/lsb_release` or `cat /etc/redhat-release`
  * [ ] StackStorm version: `st2 --version`
  * [ ] Actual package versions of all packages (st2, st2web, st2chatops, st2mistral, nginx, mongo, rabbitmq-server, postrgresql; Enterprise: st2flow, st2-auth-ldap)
    DEB: apt-cache policy ${PACKAGE_NAME} will give you the version of package.
    RPM: yum info ${PACKAGE_NAME} will you give the version of package.
    Note the exact name of mongo, nginx, rabbitmq and postgres changes based on OS.
  * [ ] Contents of /etc/st2/st2.conf
  * [ ] Output of st2ctl status
  * [ ] Optional - Details about target box. E.g. vagrant box link or AWS AMI link.

#Issue details
