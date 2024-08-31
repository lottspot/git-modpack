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
# field::
#   * `field_add     NAME VAL`
#   * `field_get     NAME`
#   * `field_get_all NAME`
#   * `fields_load   INI_PATH...`
#   * `fields_write  INI_PATH`
# errors::
#   * `runtime_error MSG`
#   * `assert_no_errors`
set -e

install_usage_spec="\
install.sh [options]

install script for %pack_name% package
--
  Options:
h,help!                  show the help
version!                 print the version number and exit
libdoc!                  print the packlib synopsis and exit
uninstall!               remove an installation created by this script
reinstall!               perform an uninstall -> install sequence
c,reconfigure!           (re-)create git config includes of sources in configsdir
abspath!                 use absolute paths for values installed into gitconfig
global!                  convenience option for -i install.scope=global
local!                   convenience option for -i install.scope=local
l,list-fields!           list all install.ini fields
f,get-field!=name        lookup an install.ini field value
i,ini!=name=val          override an install.ini assignment for this invocation
"

runtime_error()
{
  if [ "$runtime_errors" ]; then
    runtime_errors="$runtime_errors$(printf '\n%s\n' "$1")"
  else
    runtime_errors="$(printf '%s\n' "$1")"
  fi
}

assert_no_errors()
{
  if [ "$runtime_errors" ]; then
    printf 'fatal: runtime errors\n' >&2
    printf '%s\n' "$runtime_errors"  >&2
    exit 1
  fi
}
