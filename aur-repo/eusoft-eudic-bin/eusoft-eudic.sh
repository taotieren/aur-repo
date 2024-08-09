#!/bin/bash
set -euo pipefail
_APPDIR=/opt/@appname@
_RUNNAME="${_APPDIR}/@runname@"
export PATH="${_APPDIR}:${PATH}"
export LD_LIBRARY_PATH="${_APPDIR}:${_APPDIR}/lib:${LD_LIBRARY_PATH}"
export QT_PLUGIN_PATH="${_APPDIR}/plugins:${QT_PLUGIN_PATH}"
export GST_PLUGIN_SYSTEM_PATH="${_APPDIR}/lib:${GST_PLUGIN_SYSTEM_PATH}"
export GST_PLUGIN_PATH="${_APPDIR}/lib:${GST_PLUGIN_PATH}"
exec "${_RUNNAME}" "$@" || exit $?