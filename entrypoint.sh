#!/usr/bin/env bash
set -Euo pipefail

export LD_LIBRARY_PATH="/opt/legacy-libs:$WLD/lib:"

log() { echo "[$(date +'%F %T')] $*"; }

apply_authd_jdbc() {
  local AUTH_XML="${WLD}/authd/table.xml"
  [[ -f "$AUTH_XML" ]] || { log "WARN: $AUTH_XML 不存在，跳过 JDBC 覆盖"; return; }

  sed -i -E "s#url=\"jdbc:mysql://[^\"]*#url=\"jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?useUnicode=true\\&amp;characterEncoding=utf8#g" "$AUTH_XML"
  sed -i -E "s#username=\"[^\"]*\"#username=\"${DB_USER}\"#g" "$AUTH_XML"
  sed -i -E "s#password=\"[^\"]*\"#password=\"${DB_PASS}\"#g" "$AUTH_XML"
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
  st=$?
  log "==> 有子进程退出 code=${st} 容器保持运行"
  tail -f /dev/null
}

run_toplist() {
  umask 022
  mkdir -p /var/lock "$WLD/toplist"

  exec 9>"$WLD/toplist/top57.lock"
  if ! flock -n 9; then
    echo "WARN: toplist 已在运行, 退出"
    exit 0
  fi

  rm -rf "$WLD/toplist/dbhomewdb"
  cp -a "$WLD/gamedbd/dbhomewdb" "$WLD/toplist/dbhomewdb"

  log "排行榜刷新开始..."
  exec nice -n 10 ionice -c2 -n7 \
    "$WLD/toplist/toplist" \
    "$WLD/toplist/toplist.conf" \
    "$WLD/toplist/dbhomewdb"
}

ROLE="${ROLE:-core}"
case "$ROLE" in
  core)    run_core ;;
  toplist) run_toplist ;;
  *)       echo "未知 ROLE=$ROLE(支持: core/gsx/toplist)" ; exit 2 ;;
esac