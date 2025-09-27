#!/usr/bin/env bash
set -Eeuo pipefail

WLD="${WLD:-/root/wlserver57}"
export LD_LIBRARY_PATH="/opt/legacy-libs:${LD_LIBRARY_PATH:-}"
export TZ="${TZ:-UTC}"

log() { echo "[$(date +'%F %T')] $*"; }

run_gsx() {
  local CONF_DIR="${WLD}/gamed"
  local ALIAS_CONF="${GS_ALIAS_FILE:?must set GS_ALIAS_FILE}"
  log "start gsx with alias=${ALIAS_CONF}"
  cd "$CONF_DIR"
  exec ./gs gs.conf gmserver.conf "${ALIAS_CONF}"
}

run_log() {
  log "start logservice"
  cd "${WLD}/logservice"
  exec ./logservice logservice.conf
}

ROLE="${ROLE:-gsx}"
case "$ROLE" in
  gsx) run_gsx ;;
  log) run_log ;;
  *) log "未知 ROLE=$ROLE (支持: gsx/log)"; exit 2 ;;
esac