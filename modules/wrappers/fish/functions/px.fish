# proxy-run: 临时创建 proxychains 配置并运行命令
#
# 用法: px <command> [args...]
#
# 代理设置可通过环境变量覆盖: PROXY_TYPE PROXY_HOST PROXY_PORT PROXY_USER PROXY_PASS
# 注：这里是 fish 函数，不能用 exec 执行目标命令（那会替换掉当前 shell），
# 因此改为普通执行，并在命令结束后清理临时配置。

set -l proxy_type http
set -l proxy_host 127.0.0.1
set -l proxy_port 8080
set -l proxy_user
set -l proxy_pass

set -q PROXY_TYPE; and test -n "$PROXY_TYPE"; and set proxy_type $PROXY_TYPE
set -q PROXY_HOST; and test -n "$PROXY_HOST"; and set proxy_host $PROXY_HOST
set -q PROXY_PORT; and test -n "$PROXY_PORT"; and set proxy_port $PROXY_PORT
set -q PROXY_USER; and set proxy_user $PROXY_USER
set -q PROXY_PASS; and set proxy_pass $PROXY_PASS

# 自动选择可用的 proxychains 命令
set -l proxychains_bin
if command -q proxychains4
    set proxychains_bin proxychains4
else if command -q proxychains
    set proxychains_bin proxychains
else
    echo "错误：未找到 proxychains 或 proxychains4 命令" >&2
    return 1
end

# 生成临时配置文件
set -l conf_file (command mktemp /tmp/proxychains_XXXXXX.conf)
or begin
    echo "错误：无法创建临时配置文件" >&2
    return 1
end

set -l proxy_line "$proxy_type $proxy_host $proxy_port"
if test -n "$proxy_user"
    set proxy_line "$proxy_line $proxy_user $proxy_pass"
end

if not printf '%s\n' \
    '# 由 px 临时生成的配置' \
    strict_chain \
    proxy_dns \
    quiet_mode \
    '' \
    '[ProxyList]' \
    $proxy_line > $conf_file
    echo "错误：无法写入临时配置文件 $conf_file" >&2
    command rm -f $conf_file
    return 1
end

# 执行目标命令，保留其退出码
$proxychains_bin -f $conf_file $argv
set -l ret $status

command rm -f $conf_file
return $ret
