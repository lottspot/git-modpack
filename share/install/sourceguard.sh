if [[ $BASH_SOURCE ]] && [[ $0 != $BASH_SOURCE ]]; then
  PACKDIR=$(dirname "$BASH_SOURCE")
  if readlink "$PACKDIR" &>/dev/null; then
    PACKDIR=$(readlink "$PACKDIR")
  fi
  ABSPACKDIR=$(path_realpath "$PACKDIR")
  return 0
fi
