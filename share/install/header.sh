#!/usr/bin/env bash
# = packlib =
#
# path::
#   * `path_realpath    PATH`
#   * `path_norm        PATH`
#   * `path_relfrom     DEST STARTDIR`
# env::
#   * `env_str_add      VAR=VAL...`
#   * `env_str_reset`
#   * `env_file_add     PATH...`
#   * `env_file_reset`
#   * `env_exec         ARGV...`
#   * `env_eval         SHELLSTR...`
# property::
#   * `property_add     KEY VAL`
#   * `property_get     KEY`
#   * `property_get_all KEY`
#   * `proprties_load   PATH...`
#   * `proprties_write  PATH`
set -e

install_usage_spec="\
install.sh [options]

install script for %pack_name% package
--
  Options:
h,help!                  show the help
version!                 print the version number and exit
uninstall!               remove an installation created by this script
reinstall!               perform an uninstall -> install sequence
c,reconfigure!           (re-)create git config includes of sources in configsdir
abspath!                 use absolute paths for values installed into gitconfig
global!                  convenience option for -p install.scope=global
local!                   convenience option for -p install.scope=local
i,list-properties!       list all install.properties values
k,get-property!=key      lookup an install.properties value
p,with-property!=key-val override an install.properties value for this invocation
libdoc!                  print the packlib synopsis
"

input_error()
{
  if [ "$input_errors" ]; then
    input_errors="$input_errors$(printf '\n%s\n' "$1")"
  else
    input_errors="$(printf '%s\n' "$1")"
  fi
}

assert_inputs_valid()
{
  if [ "$input_errors" ]; then
    printf 'fatal: input errors\n' >&2
    printf '%s\n' "$input_errors"  >&2
    exit 1
  fi
}
