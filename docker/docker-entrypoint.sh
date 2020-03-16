#!/bin/bash
set -e

HERE=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# runtime setup of depedencies
${HERE}/install.sh --user

# interactive shell
/bin/bash "$@"
