#!/usr/bin/env bash
set -Eeuo pipefail

WLD="${WLD:-/root/wlserver57}"
export LD_LIBRARY_PATH="/opt/legacy-libs:${LD_LIBRARY_PATH:-}"
export TZ="${TZ:-UTC}"

log() { echo "[$(date +'%F %T')] $*"; }

apply_authd_jdbc() {
  local AUTH_DIR="${WLD}/authd"
  local AUTH_XML="${AUTH_DIR}/table.xml"
  local DB_HOST="${DB_HOST:-127.0.0.1}"
  local DB_PORT="${DB_PORT:-3306}"
  local DB_NAME="${DB_NAME:-wl}"
  local DB_USER="${DB_USER:-root}"
  local DB_PASS="${DB_PASS:-123456}"

  if [[ -f "$AUTH_XML" ]]; then
    sed -i -E \
      "s#url=\"jdbc:mysql://[^\"]*#url=\"jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?useUnicode=true\\&amp;characterEncoding=utf8#g" \
      "$AUTH_XML"
    sed -i -E "s#username=\"[^\"]*\"#username=\"${DB_USER}\"#g" "$AUTH_XML"
    sed -i -E "s#password=\"[^\"]*\"#password=\"${DB_PASS}\"#g" "$AUTH_XML"
  else
    log "WARN: $AUTH_XML 不存在, 跳过 JDBC 覆盖"
  fi
}

bg() { ( cd "$1" && shift && "$@" ) & }

run_core() {
  handled=false
  trap 'if ! $handled; then echo "收到停止信号, 清理..."; handled=true; fi; kill 0 || true' TERM INT

  apply_authd_jdbc

  log "start authd"
  local AD="${WLD}/authd"
  local CP="${AD}/lib/jio.jar:${AD}/lib/application.jar:${AD}/lib/commons-collections-3.1.jar:${AD}/lib/commons-dbcp-1.2.1.jar:${AD}/lib/mysql-connector-java-5.0.8-bin.jar:${AD}/lib/commons-pool-1.2.jar:${AD}/lib/commons-logging-1.0.4.jar:${AD}/lib/log4j-1.2.9.jar:${AD}"
  bg "$AD" java -cp "$CP" authd "${AD}/table.xml"
  sleep 5

  log "start logservice"
  bg "${WLD}/logservice" ./logservice logservice.conf
  sleep 5

  log "start uniquenamed"
  bg "${WLD}/uniquenamed" ./uniquenamed gamesys.conf
  sleep 5

  log "start gamedbd"
  bg "${WLD}/gamedbd" ./gamedbd gamesys.conf
  sleep 5

  log "start gdeliveryd"
  bg "${WLD}/gdeliveryd" ./gdeliveryd gamesys.conf
  sleep 5

  log "start gs"
  bg "${WLD}/gamed" ./gs gs.conf gmserver.conf gsalias.conf
  sleep 10

  log "start glinkd"
  bg "${WLD}/glinkd" ./glinkd gamesys.conf 1
  sleep 5

  log "==> 全部子进程已拉起"
  wait -n
  log "==> 有子进程退出, 容器结束"
}

run_gsx() {
  local CONF_DIR="${WLD}/gamed"
  local ALIAS_CONF="${GS_ALIAS_FILE:?must set GS_ALIAS_FILE}"
  log "start gsx with alias=${ALIAS_CONF}"
  cd "$CONF_DIR"
  exec ./gs gs.conf gmserver.conf "$ALIAS_CONF"
}

run_toplist() {
  local BASE="$WLD"
  local LIB="$BASE/lib"
  local TOPDIR="$BASE/toplist"
  local DBSRC="$BASE/gamedbd/dbhomewdb"
  local DBTMP="$TOPDIR/dbhomewdb"
  local BIN="$TOPDIR/toplist"
  local CONF="$TOPDIR/toplist.conf"
  local LOCK="/var/lock/top57.lock"

  export LD_LIBRARY_PATH="$LIB:${LD_LIBRARY_PATH:-}"
  umask 022
  mkdir -p "$(dirname "$LOCK")" "$TOPDIR"

  [[ -x "$BIN"  ]] || { echo "ERROR: $BIN 不存在或不可执行"; exit 1; }
  [[ -f "$CONF" ]] || { echo "ERROR: $CONF 不存在"; exit 1; }
  [[ -d "$DBSRC" ]]|| { echo "ERROR: 源数据目录 $DBSRC 不存在"; exit 1; }

  exec 9>"$LOCK"
  if ! flock -n 9; then
    echo "WARN: toplist 已在运行, 退出"
    exit 0
  fi

  rm -rf "$DBTMP" && cp -a "$DBSRC" "$DBTMP"
  log "toplist 一次性刷新开始..."
  exec nice -n 10 ionice -c2 -n7 "$BIN" "$CONF" "$DBTMP"
}

ROLE="${ROLE:-core}"
case "$ROLE" in
  core)    run_core ;;
  gsx)     run_gsx ;;
  toplist) run_toplist ;;
  *)       echo "未知 ROLE=$ROLE(支持: core/gsx/toplist)" ; exit 2 ;;
esac