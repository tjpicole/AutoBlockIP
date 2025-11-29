# AutoBlockIP
Enhanced auto-block script for Synology DSM (including black-synology)
AutoBlockIP for Synology DSM 7.2.2 (黑群晖适用)

## 功能
- 自动扫描 SSH/Web 登录失败记录
- 自动封锁异常 IP 到 DSM 内置封锁列表
- 强制封锁高频攻击
- 支持局域网白名单
- 输出执行日志到 `/var/log/autoblockip.log`

✔ 自动写入 DSM 封锁数据库（Web UI 瞬间可见）;

✔ 避免重复封锁（检查 DSM DB + 本地自动列表）;
✔ 支持黑群晖 DSM 7.2.2 的 sqlite3 表结构;
✔ 日志文件轮转（避免占用空间）;

## 使用方法
1. 上传 `AutoBlockIP.sh` 到 `/usr/local/bin/`
2. 赋予执行权限：
   chmod +x /usr/local/bin/AutoBlockIP.sh
