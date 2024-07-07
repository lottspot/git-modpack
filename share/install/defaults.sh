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
  packdir_localscope=$(git -C "$PACKDIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
  workdir_localscope=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)

  if [[ ! $packdir_localscope ]]; then
    printf 'global\n'
  elif [[ $packdir_localscope == $workdir_localscope ]]; then
    printf 'local\n'
  else
    printf 'EBOUNDARY\n'
  fi
}
