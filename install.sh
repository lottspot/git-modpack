#!/usr/bin/env bash

prog_dirname=$(dirname "$0")

if [[ $BASH_SOURCE ]] && [[ $0 != $BASH_SOURCE ]]; then
  prog_dirname=$(dirname "$BASH_SOURCE")
  prog_return=1
fi

prog_ini=$prog_dirname/install.ini
prog_srcs=(
  "$prog_dirname/share/install/header.sh"
  "$prog_dirname/share/install/defaults.sh"
  "$prog_dirname/share/install/packlib.sh"
  "$prog_dirname/share/install/packcore.sh"
  "$prog_dirname/share/install/sourceguard.sh"
  "$prog_dirname/share/install/gitconfig.sh"
  "$prog_dirname/share/install/mode.sh"
  "$prog_dirname/share/install/template.sh"
  "$prog_dirname/share/install/main.sh"
)

# source all fragments prior to sourceguard
for src in "${prog_srcs[@]:0:4}"; do
  source "$src"
done

if [[ $prog_return ]]; then
  PACKDIR=$prog_dirname
  ABSPACKDIR=$(path_realpath "$PACKDIR")
  return 0
fi

fields_load "$prog_ini"
exec bash -c "$(sed                                  \
  -e "s,%pack_name%,${_FIELDS['package.name']},g" \
  -e "s,%pack_version%,$(cat "$prog_dirname/VERSION"),g"  <<< "`cat "${prog_srcs[@]}"`"
  )" "$(path_realpath "$0")" "$@"
