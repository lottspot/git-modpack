#!/usr/bin/env bash
set -e

usage_spec="\
configpack-init [options] [-n|--name] PATH

Create skeleton for a new configpack project
--
  Options:
h                   show the help
n,name!=            package name (defaults to directory name)
p,property!=key-val install property
t,template!         convenience option for: -n %pack_name%
"

die(){
  printf 'configpack-init: fatal: %s\n' "$*" >&2
  exit 1
}

copy_resource()
{
  local name=$1
  local destpath=$2
  local srcpath=$DISTDIR/$name
  mkdir -p "$(dirname "$destpath")"
  sed                                                  \
    -e "s,%pack_name%,${PROPERTIES['package.name']},g" \
    -e "s,%pack_version%,$(cat "$PACKDIR/VERSION"),g"  < "$srcpath" > "$destpath"
  if [[ $(find "$srcpath" -prune -perm -00100 2>/dev/null) ]]; then
    chmod +x "$destpath"
  fi
  printf '+ %s\n' "${destpath#$NEWPACK_DESTPATH/}"
}

combine_resources()
{
  local destpath=$1
  shift
  local srcpaths=( "${@/#/$DISTDIR/}" )
  mkdir -p "$(dirname "$destpath")"
  sed                                                  \
    -e "s,%pack_name%,${PROPERTIES['package.name']},g" \
    -e "s,%pack_version%,$(cat "$PACKDIR/VERSION"),g"  <<< "`cat "${srcpaths[@]}" 2>/dev/null`" > "$destpath"
  if [[ $(find "${srcpaths[@]}" -prune -perm -00100 2>/dev/null) ]]; then
    chmod +x "$destpath"
  fi
  printf '+ %s\n' "${destpath#$NEWPACK_DESTPATH/}"
}


source "$(git configpack-packdir)/install.sh"
PACKDIR=$(git configpack-packdir)
ABSPACKDIR=$(cd "$PACKDIR" && pwd)

# Parse options
eval "$(git rev-parse --parseopt --stuck-long -- "$@" <<< "$usage_spec" || echo exit $?)"
until [[ $1 == '--' ]]; do
  opt_name=${1%%=*}
  opt_arg=${1#*=}
  case $opt_name in
    --name     ) newpack_name=$opt_arg;;
    --property )
      propkey=${opt_arg%%=*}
      propval=${opt_arg#*=}
      PROPERTIES[$propkey]=$propval
    ;;
  --template  ) pack_is_template=1;;
  esac
  shift
done

shift

# Parse operands
NEWPACK_DESTPATH=$1

# Program run

if ! [[ $NEWPACK_DESTPATH ]]; then
  printf 'error: PATH is required\n' >&2
  $0 -h
  exit 1
fi

PACK_PROPERTIES_PATH=$NEWPACK_DESTPATH/install.properties
DISTDIR=$PACKDIR/share

declare -A configs=(
  [core]=core.gitconfig
)

declare -A resources=(
  [install.sh]="
    install/header.sh
    install/defaults.sh
    install/packlib.sh
    install/packcore.sh
    install/sourceguard.sh
    install/gitconfig.sh
    install/mode.sh
    install/template.sh
    install/main.sh
  "
  [docs/help.txt]=help.txt
)

declare -A default_properties=(
  ['package.configsdir']=configs
)

if [[ $newpack_name ]]; then
  PROPERTIES['package.name']=$newpack_name
fi

if [[ $pack_is_template ]]; then
  PROPERTIES['package.name']=%pack_name%
fi

if [[ ! ${PROPERTIES['package.name']} ]]; then
  PROPERTIES['package.name']=$(default_package_name "$NEWPACK_DESTPATH")
fi

for default_name in "${!default_properties[@]}"; do
  default_val=${default_properties[$default_name]}
  if [[ ! ${PROPERTIES[$default_name]} ]]; then
    PROPERTIES[$default_name]=$default_val
  fi
done

# validate install.mode value
install_mode=${PROPERTIES['install.mode']}
if [[ $install_mode ]]; then
  $DISTDIR/install.sh --with-property "install.mode=$install_mode" --get-property install.mode >/dev/null
fi

if [[ ! -e $PACK_PROPERTIES_PATH ]]; then
  properties_write "$PACK_PROPERTIES_PATH"
fi

for conf_name in "${!configs[@]}"; do
  conf_srcs=( ${configs[$conf_name]} )
  package_configsdir=${PROPERTIES['package.configsdir']}

  if [[ $package_configsdir ]]; then
    conf_path=$NEWPACK_DESTPATH/$package_configsdir/$conf_name
  else
    conf_path=$NEWPACK_DESTPATH/$conf_name
  fi

  if [[ ! -e $conf_path ]]; then
    if [[ ${#conf_srcs[*]} -gt 1 ]]; then
      combine_resources "$conf_path" "${conf_srcs[@]}"
    else
      copy_resource "${conf_srcs[0]}" "$conf_path"
    fi
  fi
done

for resource_pathleaf in "${!resources[@]}"; do
  resource_name=${resources[$resource_pathleaf]}
  resource_srcs=( ${resources[$resource_pathleaf]} )
  resource_path=$NEWPACK_DESTPATH/$resource_pathleaf
  if [[ ! -e $resource_path ]]; then
    if [[ ${#resource_srcs[*]} -gt 1 ]]; then
      combine_resources "$resource_path" "${resource_srcs[@]}"
    else
      copy_resource "${resource_srcs[0]}" "$resource_path"
    fi
  fi
done
