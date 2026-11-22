Changelog
=========

in development
--------------

Added
~~~~~

Changed
~~~~~~~

 * Updated 3rd party services to tested/supported version for StackStorm core:
     - mongo v8.2
     - rabbitmq v4.2
     - redis v8.6
   Contributed by @nzlosh

 * Added systemd generators for st2auth, st2api, st2stream service unit files.
   Contributed by @nzlosh #762

 * The installer sets up Node.js 24 LTS (NodeSource) for ChatOps, replacing Node.js 20, which
   reached end of life in April 2026. A previous major's NodeSource repository is now removed first
   (including one written by NodeSource's own setup script), and the Ubuntu script's cleanup of old
   NodeSource files (it removed ``$i``, never set) is fixed.

Removed
~~~~~~~

* Removed focal and rocky8
  Contributed by @nzlosh + @skiedude #761


v3.9
--------------

Added
~~~~~
* Add Ubuntu Jammy packaging
  Contributed by @mamercad
