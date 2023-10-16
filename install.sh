#!/usr/bin/env bash

prog_dir=$(dirname "$0")

if [[ $BASH_SOURCE ]] && [[ $0 != $BASH_SOURCE ]]; then
  prog_dir=$(dirname "$BASH_SOURCE")
  prog_return=1
fi

prog_template=$prog_dir/share/install.sh
prog_properties=$prog_dir/install.properties

source "$prog_template"

if [[ $prog_return ]]; then
  PACKDIR=$prog_dir
  ABSPACKDIR=$(path_realpath "$PACKDIR")
  return 0
fi

properties_load "$prog_properties"
exec bash -c "$(sed                                  \
  -e "s,%pack_name%,${PROPERTIES['package.name']},g" \
  -e "s,%pack_version%,$(cat "$prog_dir/VERSION"),g"  < "$prog_template"
  )" "$(path_realpath "$0")" "$@"
