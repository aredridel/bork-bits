
action="$1"
name="$2"
shift 2
case "$action" in
  desc)
    echo "asserts systemd service state"
    echo "* systemctl enabled servicename.service"
    ;;
  status)
    baking_platform_is "Linux" || return $STATUS_UNSUPPORTED_PLATFORM
    needs_exec "systemctl"
    [ "$?" -gt 0 ] && return $STATUS_FAILED_PRECONDITION

    bake systemctl is-enabled "$name"
    [ "$?" -gt 0 ] && return $STATUS_MISSING

    return $STATUS_OK
    ;;

  install|upgrade)
    bake systemctl enable --now "$name"
    ;;

  remove)
    bake systemctl disable --now "$name"
    ;;
    
  *) return 1 ;;
esac

