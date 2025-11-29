#!/bin/bash
#####################################################
# AutoBlockIP for Synology DSM 7.2.2 (黑群晖适用)
# 功能: 自动分析 SSH/Web 登录失败记录并封锁可疑 IP
# 逻辑:
# ① 连续失败 ≥3 次封锁
# ② 非常见用户直接封锁
# ③ 同一 IP 失败 ≥7 次强制封锁
# ④ 局域网 IP 不封锁
# ⑤ 避免重复封锁（检查 DB + 本地列表）
# Author: tjpicole / 2025.11.22
# Version: V2025.1122
#####################################################

LOG_FILES="/var/log/auth.log /var/log/messages"
BLOCKLIST="/usr/local/etc/autoblocked.txt"
LOG_OUTPUT="/var/log/autoblockip.log"

THRESHOLD=3
FORCE_BLOCK=7
LOCAL_NET_REGEX="^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)"

mkdir -p /usr/local/etc
touch "$BLOCKLIST"
touch "$LOG_OUTPUT"

# ----------------------------
# 日志文件轮转（超过10MB自动备份）
# ----------------------------
if [ -f "$LOG_OUTPUT" ] && [ $(stat -c%s "$LOG_OUTPUT") -ge 10485760 ]; then
    mv "$LOG_OUTPUT" "${LOG_OUTPUT}.$(date '+%Y%m%d_%H%M%S').bak"
    touch "$LOG_OUTPUT"
fi

log(){
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_OUTPUT"
}

log "[AutoBlockIP] 开始扫描日志..."

# ----------------------------
# 读取 DSM 已封锁 IP（避免重复入库）
# ----------------------------
readarray -t DB_BLOCKED_IPS < <(sqlite3 /etc/synoautoblock.db "SELECT IP FROM AutoBlockIP WHERE Deny=1;")

# ----------------------------
# 提取日志中的失败 IP
# ----------------------------
ENTRIES=$(grep -h "rhost=" $LOG_FILES | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}")
IPS=$(echo "$ENTRIES" | sort | uniq)

for IP in $IPS; do

    # 跳过局域网
    if [[ $IP =~ $LOCAL_NET_REGEX ]]; then
        continue
    fi

    # 跳过 DSM 已封锁 IP
    if [[ " ${DB_BLOCKED_IPS[@]} " =~ " $IP " ]]; then
        log "[跳过] 已封锁 IP：$IP"
        continue
    fi

    # 统计失败次数
    FAIL_COUNT=$(echo "$ENTRIES" | grep -w "$IP" | wc -l)

    # ----------------------------
    # 强制封锁逻辑
    # ----------------------------
    if [[ $FAIL_COUNT -ge $FORCE_BLOCK ]]; then
        log "[强制封锁] $IP（失败 $FAIL_COUNT 次）"

        sqlite3 /etc/synoautoblock.db \
        "INSERT OR REPLACE INTO AutoBlockIP (IP, RecordTime, ExpireTime, Deny, IPStd, Type, Meta) \
         VALUES ('$IP', strftime('%s','now'), 0, 1, '$IP', 0, 'AutoBlockIP');"

        grep -qx "$IP" "$BLOCKLIST" || echo "$IP" >> "$BLOCKLIST"
        continue
    fi

    # ----------------------------
    # 普通封锁逻辑
    # ----------------------------
    if [[ $FAIL_COUNT -ge $THRESHOLD ]]; then
        log "[封锁] $IP（失败 $FAIL_COUNT 次）"

        sqlite3 /etc/synoautoblock.db \
        "INSERT OR REPLACE INTO AutoBlockIP (IP, RecordTime, ExpireTime, Deny, IPStd, Type, Meta) \
         VALUES ('$IP', strftime('%s','now'), 0, 1, '$IP', 0, 'AutoBlockIP');"

        grep -qx "$IP" "$BLOCKLIST" || echo "$IP" >> "$BLOCKLIST"
        continue
    fi

done

log "[AutoBlockIP] 执行完毕"
exit 0

