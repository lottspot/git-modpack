core_newalias()
{
  local alias_name=$1
  local alias_cmd=$2
  local alias_config=$PACKDIR/$($PACKDIR/install.sh --get-field=package.configsdir)/$alias_name
  local helpdoc=$PACKDIR/docs/help.txt
  local awk_prog='
{ divcol = index($0, "::") }
END {
  aliaslen = length(newalias)
  aliaslen >= divcol ? divcol = aliaslen + 2 : divcol = divcol - (aliaslen +1)
  printf "%s" sprintf("%%%ds", divcol) "::\n", newalias, ""
}
'
  if [[ ! $alias_name ]]; then
    printf 'usage: newalias ALIAS_NAME [ALIAS_CMD]\n' >&2
    exit 1
  fi

  if ! [[ $alias_cmd ]]; then
    alias_cmd=!false
  fi

  git config --file="$alias_config" --add alias."$alias_name" "$alias_cmd"
  printf '>> %s\n' "${alias_config#$PACKDIR/}"
  $PACKDIR/install.sh --reconfigure
  if [[ -w $helpdoc ]]; then
    awk -v newalias="$alias_name" "$awk_prog" < "$helpdoc" >> "$helpdoc"
    printf '>> %s\n' "${helpdoc#$PACKDIR/}"
  fi
}

core_newprog()
{
  local alias_name=$1
  local progsdir=$PACKDIR/$($PACKDIR/install.sh --get-field=package.progsdir)
  local package_name=$($PACKDIR/install.sh --get-field=package.name)
  local alias_script_name=$alias_name.sh
  local alias_script_path=$progsdir/$alias_script_name
  local alias_script_skel=$(cat <<'EOF' | sed -E "s,%alias_name%,$alias_name,g"
#!/usr/bin/env bash
set -e

usage_spec="\
%alias_name% [options]

alias program %alias_name%
--
  Options:
h             show the help
echo!?CONTENT  print <CONTENT> and immediately exit
"

eval "$(git rev-parse --parseopt --stuck-long -- "$@" <<< "$usage_spec" || echo exit $?)"
until [[ $1 == '--' ]]; do
  case $1 in
    --*)
      opt_name=${1%%=*}
      opt_arg=${1#*=}
      if [[ $opt_name == $opt_arg ]]; then
        opt_arg=
      fi
    ;;
    -[^-]*)
      opt_name=${1:0:2}
      opt_arg=${1:2}
    ;;
  esac
  case $opt_name in
    --echo) if [[ $opt_arg ]]; then echo "$opt_arg"; fi; exit 0;;
  esac
  shift
done
shift
EOF
)

  if [[ ! $alias_name ]]; then
    printf 'usage: newprog PROG_NAME\n' >&2
    exit 1
  fi

  if [[ -e "$alias_script_path" ]]; then
    exit 0
  fi

  mkdir -p "$progsdir"
  core_newalias "$alias_name" "!exec \"\`git $package_name-progsdir\`/$alias_script_name\""
  printf '%s\n' "$alias_script_skel" > "$alias_script_path"
  chmod +x "$alias_script_path"
  printf '+ %s\n' "${alias_script_path#$PACKDIR/}"
}

if [[ $BASH_SOURCE ]] && [[ $0 != $BASH_SOURCE ]]; then
  PACKDIR=$(dirname "$BASH_SOURCE")
  if readlink "$PACKDIR" &>/dev/null; then
    PACKDIR=$(readlink "$PACKDIR")
  fi
  ABSPACKDIR=$(path_realpath "$PACKDIR")
  return 0
fi
