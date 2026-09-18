if test (count $argv) -eq 0
    # 如果没有参数，则取消所有代理设置
    set -e http_proxy
    set -e https_proxy
    set -e ftp_proxy
    set -e all_proxy
    set -e NODE_EXTRA_CA_CERTS
    set -e NODE_TLS_REJECT_UNAUTHORIZED
    echo "Proxy settings cleared"
else if test (count $argv) -eq 1
    # 如果有一个参数，则设置为该代理地址
    set -gx http_proxy $argv[1]
    set -gx https_proxy $argv[1]
    set -gx ftp_proxy $argv[1]
    set -gx all_proxy $argv[1]
    set -gx NODE_EXTRA_CA_CERTS "/Users/$USER/.mitmproxy/mitmproxy-ca-cert.pem"
    set -gx NODE_TLS_REJECT_UNAUTHORIZED 0
    echo "Proxy set to $argv[1]"
else
    # 参数数量不正确时显示用法
    echo "Usage: setproxy [proxy_url]"
    echo "Example: setproxy http://proxy.example.com:8080"
    echo "To clear proxy: setproxy"
end
