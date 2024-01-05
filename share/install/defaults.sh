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
  local gitconfig_scope=
  local tmpkey=x$(dd if=/dev/urandom bs=1 count=4 status=none | od -A n -t x1 | tr -d '[:space:]')
  git config --replace-all configpacktmp.$tmpkey true
  gitconfig_scope=$(
    git config --get --show-scope configpacktmp.$tmpkey |
    cut -d$'\t' -f1
  )
  git config --unset-all configpacktmp.$tmpkey
  printf '%s\n' "$gitconfig_scope"
}

