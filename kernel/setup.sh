#!/bin/sh
set -eu

GKI_ROOT=$(pwd)

display_usage() {
    echo "Usage: $0 [--cleanup | <commit-or-tag>]"
    echo "  --cleanup:              Cleans up previous modifications made by the script."
    echo "  <commit-or-tag>:        Sets up or updates the KernelSU-Next to specified tag or commit."
    echo "  -h, --help:             Displays this usage information."
    echo "  (no args):              Sets up or updates the KernelSU-Next environment to the default susfs-next branch."
}

initialize_variables() {
    if test -d "$GKI_ROOT/common/drivers"; then
        DRIVER_DIR="$GKI_ROOT/common/drivers"
    elif test -d "$GKI_ROOT/drivers"; then
        DRIVER_DIR="$GKI_ROOT/drivers"
    else
        echo '[ERROR] "drivers/" directory not found.'
        exit 127
    fi

    DRIVER_MAKEFILE=$DRIVER_DIR/Makefile
    DRIVER_KCONFIG=$DRIVER_DIR/Kconfig
}

perform_cleanup() {
    echo "[+] Cleaning up..."
    [ -L "$DRIVER_DIR/kernelsu" ] && rm "$DRIVER_DIR/kernelsu" && echo "[-] Symlink removed."
    grep -q "kernelsu" "$DRIVER_MAKEFILE" && sed -i '/kernelsu/d' "$DRIVER_MAKEFILE" && echo "[-] Makefile reverted."
    grep -q "drivers/kernelsu/Kconfig" "$DRIVER_KCONFIG" && sed -i '/drivers\/kernelsu\/Kconfig/d' "$DRIVER_KCONFIG" && echo "[-] Kconfig reverted."
    if [ -d "$GKI_ROOT/KernelSU-Next" ]; then
        rm -rf "$GKI_ROOT/KernelSU-Next" && echo "[-] KernelSU-Next directory deleted."
    fi
}

setup_kernelsu() {
    echo "[+] Setting up KernelSU-Next..."
    if [ ! -d "$GKI_ROOT/KernelSU-Next" ]; then
        git clone -b susfs-next https://github.com/farrukh2002/ksunext.git KernelSU-Next && echo "[+] Repository cloned."
    fi
    cd "$GKI_ROOT/KernelSU-Next"
    git stash && echo "[-] Stashed current changes."
    git pull && echo "[+] Repository updated."

    if [ -n "${1-}" ]; then
        git checkout "$1" && echo "[-] Checked out $1." || echo "[!] Failed to checkout $1."
    fi

    cd "$DRIVER_DIR"
    ln -sf "$(realpath --relative-to="$DRIVER_DIR" "$GKI_ROOT/KernelSU-Next/kernel")" "kernelsu" && echo "[+] Symlink created."

    grep -q "kernelsu" "$DRIVER_MAKEFILE" || printf "\nobj-\$(CONFIG_KSU) += kernelsu/\n" >> "$DRIVER_MAKEFILE" && echo "[+] Modified Makefile."
    grep -q "source \"drivers/kernelsu/Kconfig\"" "$DRIVER_KCONFIG" || sed -i "/endmenu/i\source \"drivers/kernelsu/Kconfig\"" "$DRIVER_KCONFIG" && echo "[+] Modified Kconfig."
    echo '[+] Done.'
}

if [ "$#" -eq 0 ]; then
    initialize_variables
    setup_kernelsu
elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    display_usage
elif [ "$1" = "--cleanup" ]; then
    initialize_variables
    perform_cleanup
else
    initialize_variables
    setup_kernelsu "$@"
fi
