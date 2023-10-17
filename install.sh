#!/usr/bin/env bash

prog_dir=$(dirname "$0")
prog_template=$prog_dir/share/install.sh
prog_properties=$prog_dir/install.properties
source "$prog_template"
properties_load "$prog_properties"
exec bash -c "$(sed                                  \
  -e "s,%pack_name%,${PROPERTIES['package.name']},g" \
  -e "s,%pack_version%,$(cat "$prog_dir/VERSION"),g"  < "$prog_template"
  )" "$(path_realpath "$0")" "$@"
