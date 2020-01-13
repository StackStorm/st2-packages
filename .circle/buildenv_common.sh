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

# NOTE: We don't build Mistral package on Ubuntu Bionic
if [[ "${DISTRO}" = "bionic"} ]] || [[ "${DISTRO}" = "el8"} ]]; then
    ST2_PACKAGES="st2"
else
    ST2_PACKAGES=${ST2_PACKAGES:-st2 mistral}
fi

write_env ST2_PACKAGES

cat ~/.buildenv
