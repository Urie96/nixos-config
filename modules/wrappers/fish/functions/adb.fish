if [ -z "$ANDROID_SERIAL" ]
    set -gx ANDROID_SERIAL (command adb devices -l | grep -E '\sdevice\s' | fzf --bind one:accept --exit-0 | awk '{print $1}')
end
switch $argv[1]
    case setproxy
        command adb shell settings put global http_proxy $argv
    case unproxy
        command adb shell settings put global http_proxy :0
    case termux
        command adb shell -t exec run-as com.termux sh -c (string escape "export HOME=/data/data/com.termux/files/home; export PATH=/data/data/com.termux/files/usr/bin:\$PATH; export LD_PRELOAD=/data/data/com.termux/files/usr/lib/libtermux-exec.so; export SHELL=/data/data/com.termux/files/usr/bin/fish; cd \$HOME; \$SHELL")
    case '*'
        command adb $argv
end
