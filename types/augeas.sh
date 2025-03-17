
action="$1"
setx="$2"
target="$3"
value="$4"
shift 4

if [ $setx != 'set' ]; then
  echo "only command supported is set" 1>&2
  return $STATUS_BAD_ARGUMENTS
fi

case "$action" in
  desc)
    echo "sets specific values in configuration files"
    echo "* augeas set target value"
    ;;
  status)
    needs_exec "augtool"
    [ "$?" -gt 0 ] && return $STATUS_FAILED_PRECONDITION

    bake augtool ls "$target" || return $STATUS_MISSING

    [ "$(bake augtool get "$target")" = "$target = $value" ] || return $STATUS_OUTDATED

    return $STATUS_OK
    ;;

  install|upgrade)
    bake augtool set "$target" "$value"
    ;;

  *) return 1 ;;
esac

