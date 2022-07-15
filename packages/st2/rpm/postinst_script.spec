set -e

# Reload systemd to run generators for unit and socket files.
systemctl daemon-reload >/dev/null 2>&1 || true

# Enable services created by systemd generator
systemctl enable st2api st2auth st2stream >/dev/null 2>&1  || true
systemctl start st2api st2auth st2stream >/dev/null 2>&1  || true
