# Write export lines into ~/.buildenv and also source it in ~/.circlerc
write_env() {
  for e in $*; do
    eval "value=\$$e"
    [ -z "$value" ] || echo "export $e=$value" >> ~/.buildenv
  done
  echo ". ~/.buildenv" >> ~/.circlerc
}

distros=($DISTROS)
DISTRO=${distros[$CIRCLE_NODE_INDEX]}

ST2_PACKAGES="st2"

write_env ST2_PACKAGES

cat ~/.buildenv
