apt_install() {
    # Installation for deb based systems using apt.
    #   --use-sudo : run the package manager(PM) with sudo command (this is for internal use only, not an end-user option)
    #   --yes      : Automatically respond yes to PM questions.
    SUDO=""
    YES_FLAG=""
    declare -a PKGS=()
    for opt in $@
    do
        case $opt in
            --use-sudo)
                SUDO="sudo"
                shift
                ;;
            --yes)
                YES_FLAG="-y"
                shift
                ;;
            *)
                # pass any unknown keywords from the caller directly to the PM.
                PKGS+=($opt)
                ;;
        esac
    done

    $SUDO apt $YES_FLAG install ${PKGS[@]}
}

