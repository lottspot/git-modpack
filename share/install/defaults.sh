default_package_name()
{
  local packdir=$1
  local pack_basename=$(basename "$packdir")
  if [[ $pack_basename =~ ^\.+$ ]]; then
    pack_basename=$(basename "$(cd "$packdir" && pwd)")
  fi
  local pack_name=${pack_basename#.}
  pack_name=${pack_name#git-}
  printf '%s\n' "$pack_name"
}

default_install_scope()
{
  if git config --local -l &>/dev/null; then
    printf 'local\n'
  else
    printf 'global\n'
  fi
}

