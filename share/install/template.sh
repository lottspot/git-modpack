pack_is_template()
{
  if grep '[%]pack_name[%]' <<< "${PROPERTIES['package.name']}" >/dev/null; then
    return 0
  else
    return 1
  fi
}

pack_rename()
{
  local new_name=$1
  local packrename_dir=$PACKDIR/.packrename
  find "$PACKDIR" -type f ! -path '*/.*' -exec sed -i.packrename -e "s/[%]pack_name[%]/$new_name/g" {} +
  find "$PACKDIR" -type f -name '*.packrename' | while read packrename_src; do
    packrename_stem=${packrename_src#$PACKDIR}
    packrename_base=${packrename_stem%.packrename}
    packrename_dest=$packrename_dir/$packrename_base
    mkdir -p "$(dirname "$packrename_dest")"
    mv "$packrename_src" "$packrename_dest"
    printf '+ %s\n' "$packrename_dest"
  done
}

