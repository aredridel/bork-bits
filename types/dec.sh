
action="$1"
targetfile="$2"
src="$3"
seed="$4"
key="$5"
shift 5

case "$action" in
  desc)
    echo "decrypts using ssh-agent signature as a key"
    echo "* dec dest-file src-file seed key"
    ;;
  status)
    needs_exec "openssl"
    [ "$?" -gt 0 ] && return $STATUS_FAILED_PRECONDITION
    needs_exec "base64"
    [ "$?" -gt 0 ] && return $STATUS_FAILED_PRECONDITION
    needs_exec "gzip"
    [ "$?" -gt 0 ] && return $STATUS_FAILED_PRECONDITION
    needs_exec "ssh-add"
    [ "$?" -gt 0 ] && return $STATUS_FAILED_PRECONDITION

    bake [ -f "$targetfile" ] || return $STATUS_MISSING

    return $STATUS_OK
    ;;

  install|upgrade)
    bake ssh-crypt -d "$seed" "$key" < "$src" > "$targetfile"
    ;;

  *) return 1 ;;
esac

