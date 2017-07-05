# Write export lines into ~/.buildenv and also source it in ~/.circlerc
write_env() {
  for e in $*; do
    eval "value=\$$e"
    [ -z "$value" ] || echo "export $e=$value" >> ~/.buildenv
  done

  # compatibility with CircleCI 2.0
  if [ -n "$CIRCLE_ENV" ]; then
    CIRCLE_ENV="~/.circlerc"
  fi

  echo ". ~/.buildenv" >> $CIRCLE_ENV
}
