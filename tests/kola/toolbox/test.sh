#!/bin/bash

# Make sure that basic toolbox functionnality is working:
# - Creating a toolbox
# - Running a command in a toolbox
# - Removing all toolbox containers
#
# Important note: Commands are run indirectly via calls to `machinectl shell`
# to re-create the user environment needed for unprivileged podman
# functionality. However, machinectl shell does not propagate the exit
# code/status of the invoked shell process thus we need additionnal checks to
# ensure that previous commands were successful.

# Only run on QEMU to reduce CI costs as nothing is platform specific here.
# kola: { "tags": "needs-internet", "platforms": "qemu-unpriv" }

set -xeuo pipefail

ok() {
    echo "ok" "$@"
}

fatal() {
    echo "$@" >&2
    exit 1
}

machinectl shell core@ /bin/toolbox create --assumeyes 1>/dev/null
if [[ $(machinectl shell core@ /bin/toolbox list --containers | grep --count fedora-toolbox-) -ne 1 ]]; then
	fatal "Could not create toolbox"
fi
ok toolbox create

machinectl shell core@ /bin/toolbox run touch ok_toolbox
if [[ ! -f '/home/core/ok_toolbox' ]]; then
	fatal "Could not run a simple command inside a toolbox"
fi
ok toolbox run

toolbox="$(machinectl shell core@ /bin/toolbox list --containers | grep fedora-toolbox- | awk '{print $2}')"
machinectl shell core@ /bin/podman stop "${toolbox}"
machinectl shell core@ /bin/toolbox rm "${toolbox}"
if [[ -n "$(machinectl shell core@ /bin/toolbox list --containers)" ]]; then
	fatal "Could not remove the toolbox container"
fi
ok toolbox rm
