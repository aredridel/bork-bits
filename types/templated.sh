# TODO change compiled filename transformation to md5 representation instead of base64
# TODO any way to test for sudo???

action="$1"
targetfile="$2"
sourcefile="$3"
substitutions="$4"
shift 4

perms="$(arguments get permissions $*)"
owner="$(arguments get owner $*)"
_bake () {
  if [ -n "$owner" ]; then
    bake sudo $@
  else bake $@
  fi
}
file_varname="borkfiles__$(echo "$sourcefile" | base64 | sed -E 's|\+|_|' | sed -E 's|\?|__|' | sed -E 's|=+||')"
target_platform="$(get_baking_platform)"

case "$action" in
  desc)
    echo "asserts the presence, checksum, owner and permissions of a file, and "
    echo "applies sed substitutions"
    echo "* templated target-path source-path substitutions [arguments]"
    echo "--permissions=755       permissions for the file"
    echo "--owner=owner-name      owner name of the file"
    ;;
  status)

    if ! is_compiled && [ ! -f "$sourcefile" ]; then
      echo "source file doesn't exist: $sourcefile"
      return $STATUS_FAILED_ARGUMENTS
    fi
    if [ -n "$owner" ]; then
      owner_id="$(bake id -u $owner)"
      if [ "$?" -gt 0 ]; then
        echo "unknown owner: $owner"
        return $STATUS_FAILED_ARGUMENT_PRECONDITION
      fi
    fi

    bake [ -f "$targetfile" ] || return $STATUS_MISSING

    md5c="$(md5cmd $target_platform)"
    if is_compiled; then
      sourcesum="$(echo "${!file_varname}" | base64 --decode | sed -e "$substitutions" | eval $md5c)"
    else
      sourcesum="$(sed -e "$substitutions" < "$sourcefile" | eval $md5c)"
    fi
    targetsum="$(_bake $(md5cmd $target_platform "$targetfile"))"
    if [ "$targetsum" != "$sourcesum" ]; then
      echo "expected sum: $sourcesum"
      echo "received sum: $targetsum"
      return $STATUS_CONFLICT_UPGRADE
    fi

    mismatch=
    if [ -n "$perms" ]; then
      existing_perms=$(_bake $(permission_cmd $target_platform) "$targetfile")
      if [ "$existing_perms" != "$perms" ]; then
        echo "expected permissions: $perms"
        echo "received permissions: $existing_perms"
        mismatch=1
      fi
    fi
    if [ -n "$owner" ]; then
      existing_user=$(_bake ls -l "$targetfile" | awk '{print $3}')
      if [ "$existing_user" != $owner ]; then
        echo "expected owner: $owner"
        echo "received owner: $existing_user"
        mismatch=1
      fi
    fi
    [ -n "$mismatch" ] && return $STATUS_MISMATCH_UPGRADE
    return 0
    ;;

  install|upgrade)
    dirn="$(dirname "$targetfile")"
    [ "$dirn" != . ] && _bake mkdir -p "$dirn"
    [ -n "$owner" ] && _bake chown "$owner" "$dirn"
    if is_compiled; then
      _bake "echo \"${!file_varname}\" | base64 --decode | sed -e '$substitutions' > '$targetfile'"
    else
      _bake sed -e "$substitutions" < "$sourcefile" > "$targetfile"
    fi
    [ -n "$owner" ] && _bake chown "$owner" "$targetfile"
    [ -n "$perms" ] && _bake chmod "$perms" "$targetfile"
    return 0
    ;;

  remove)
    _bake rm "$targetfile"
    ;;

  compile)
    if [ ! -f "$sourcefile" ]; then
      echo "fatal: file '$sourcefile' does not exist!" 1>&2
      exit 1
    fi
    if [ ! -r "$sourcefile" ]; then
      echo "fatal: you do not have read permission for file '$sourcefile'"
      exit 1
    fi
    echo "# source: $sourcefile"
    echo "# md5 sum: $(eval $(md5cmd $target_platform $sourcefile))"
    echo "$file_varname=\"$(cat $sourcefile | base64)\""
    ;;

  *) return 1 ;;
esac
