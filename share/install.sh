#!/usr/bin/env bash
set -e

usage_spec="\
install.sh [options]

install script for %pack_name% package
--
  Options:
h,help                   show the help
uninstall                remove an installation created by this script
reinstall                perform an uninstall -> install sequence
c,reconfigure            (re-)create git config includes of sources in configsdir
l,list-properties        list all install.properties values
k,get-property=key       lookup an install.properties value
p,with-property=key-val  override an install.properties value for this invocation
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

default_package_name()
{
  local pack_basename=$(basename "$PACKDIR")
  if [[ $pack_basename =~ ^\.+$ ]]; then
    pack_basename=$(basename "$(cd "$PACKDIR" && pwd)")
  fi
  local pack_name=${pack_basename#.}
  pack_name=${pack_name#git-}
  printf '%s\n' "$pack_name"
}

property_get()
{
  local prop_name=$1
  printf '%s\n' "${properties[$prop_name]}" | tail -n1
}

property_get_all()
{
  local prop_name=$1
  printf '%s\n' "${properties[$prop_name]}"
}

property_add()
{
  local prop_key=$1
  local prop_val=$2
  if [[ ${properties[$prop_key]} ]]; then
    properties[$prop_key]=$(printf '%s\n%s\n' "${properties[$prop_key]}" "$prop_val")
  else
    properties[$prop_key]=$prop_val
  fi
}

load_properties()
{
  frompath=$1
  while read prop_key prop_val; do
    test "$prop_key" || continue
    property_add "$prop_key" "$prop_val"
  done <<< "$(git config -f "$frompath" --get-regexp '.*')"
}

write_gitconfig()
{
  while read config_path; do
    test "$config_path" || continue
    config_path=$(sed 's|/./|/|g' <<< "$config_path")
    path_args=("$config_path")
    if ! grep -- '--unset' &>/dev/null <<< "$*"; then
      path_args+=("$config_path")
    fi
    git config "${GIT_CONFIG_OPTS[@]}" --fixed-value "$@" include.path "${path_args[@]}"
  done <<< "$(find "$ABSPACKDIR/$PACKAGE_CONFIGSDIR" -maxdepth 1 -mindepth 1 -type f ! -name '.*' ! -name install.sh ! -name install.properties 2>/dev/null)"
}

mode_install()
{
  while read hook; do
    ( eval "$hook" )
  done <<< "$(property_get_all 'install.pre')"

  if [[ ! -e $INSTALLDIR ]]; then
    mkdir -p "$(dirname "$INSTALLDIR")"
    ln -s "$ABSPACKDIR" "$INSTALLDIR"
    printf '+ %s\n' "$INSTALLDIR"
  fi

  write_gitconfig
  git config "${GIT_CONFIG_OPTS[@]}" --replace-all configpack.$PACKAGE_NAME.installdir "$INSTALLDIR"

  while read hook; do
    ( eval "$hook" )
  done <<< "$(property_get_all 'install.post')"
}

mode_uninstall()
{
  while read hook; do
    ( eval "$hook" )
  done <<< "$(property_get_all 'uninstall.pre')"

  if find "$INSTALLDIR" -prune &>/dev/null; then
    was_installed=1
  fi

  if [[ $INSTALLDIR != $PACKDIR ]]; then
    rm -f "$INSTALLDIR"
  fi

  if [[ $was_installed ]] && ! find "$INSTALLDIR" -prune &>/dev/null; then
    printf -- '- %s\n' "$INSTALLDIR"
  fi

  write_gitconfig --unset
  git config "${GIT_CONFIG_OPTS[@]}" --unset-all configpack.$PACKAGE_NAME.installdir

  while read hook; do
    ( eval "$hook" )
  done <<< "$(property_get_all 'uninstall.post')"
}

mode_list_properties()
{
  local properties_table=$(for prop_name in "${!properties[@]}"; do printf '%s %s\n' "$prop_name" "${properties[$prop_name]}"; done)
  local awk_prog='
BEGIN {
  maxlen=0
}
{
  fieldlen=length($1)
  if (fieldlen > maxlen) maxlen=fieldlen
  field[NR]=$1
  val[NR]=substr($0, fieldlen+2)
}
END {
  fstr = sprintf("%%-%ds  %%s\n", maxlen)
  for (i = 1; i <= NR; i++) printf(fstr, field[i], val[i])
}
'
  awk "$awk_prog" <<< "$properties_table"
}

PACKDIR=$(dirname "$0")

if readlink "$PACKDIR" &>/dev/null; then
  PACKDIR=$(readlink "$PACKDIR")
fi

ABSPACKDIR=$(cd "$PACKDIR" && pwd)
INSTALLDIR=
properties_path=$PACKDIR/install.properties
declare -A properties
declare -A default_properties=(
  [package.name]=$(default_package_name)
  [package.configsdir]=.
  [install.mode]=static-local
)

if [[ -e $properties_path ]]; then
  load_properties "$properties_path"
fi

eval "$(git rev-parse --parseopt --stuck-long -- "$@" <<< "$usage_spec" || echo exit $?)"
until [[ $1 == '--' ]]; do
  opt_name=${1%%=*}
  opt_arg=${1#*=}
  case $opt_name in
    --reconfigure     ) modes+=(reconfigure)       ;;
    --uninstall       ) modes+=(uninstall)         ;;
    --reinstall       ) modes+=(uninstall install) ;;
    --list-properties ) modes+=(list-properties)   ;;
    --get-property    )
      modes+=(get-property)
      get_prop_name=$opt_arg
    ;;
    --with-property   )
      propkey=${opt_arg%%=*}
      propval=${opt_arg#*=}
      property_add "$propkey" "$propval"
    ;;
  esac
  shift
done

for prop_name in "${!default_properties[@]}"; do
  prop_val=${default_properties[$prop_name]}
  if [[ ! ${properties[$prop_name]} ]]; then
    properties[$prop_name]=$prop_val
  fi
done

if ! [[ $modes ]]; then
  modes=(install)
fi

PACKAGE_NAME=$(property_get 'package.name')
PACKAGE_CONFIGSDIR=$(property_get 'package.configsdir')
INSTALL_MODE=$(property_get 'install.mode')
GIT_CONFIG_OPTS=()

case $INSTALL_MODE in
  local)
    INSTALLDIR=$(git rev-parse --git-path "$PACKAGE_NAME")
  ;;
  global)
    INSTALLDIR=$HOME/.local/share/git-$PACKAGE_NAME
    GIT_CONFIG_OPTS+=(--global)
  ;;
  static-local)
    INSTALLDIR=$PACKDIR
  ;;
  static-global)
    INSTALLDIR=$PACKDIR
    GIT_CONFIG_OPTS+=(--global)
  ;;
  *)
    input_error "invalid install.mode: $INSTALL_MODE; must be one of: local, global, static-local, static-global"
  ;;
esac

assert_inputs_valid

for mode in "${modes[@]}"; do
  case $mode in
    install         ) mode_install                      ;;
    uninstall       ) mode_uninstall                    ;;
    reconfigure     ) write_gitconfig                   ;;
    list-properties ) mode_list_properties              ;;
    get-property    ) property_get_all "$get_prop_name" ;;
  esac
done
