import argparse
import os
import subprocess
from typing import List, NamedTuple, Optional

from kittens.ssh.utils import get_connection_data
from kittens.tui.handler import result_handler
from kitty.boss import Boss

# nix 打包时替换成 store 里的绝对路径，见 modules/wrappers/kitty/module.nix 的
# substituteScriptVars 和 ./default.nix 的 scriptVars
MPV = "@MPV@"
RSYNC_TOOL = "@RSYNC_TOOL@"


def main(args: List[str]):
    pass


@result_handler(no_ui=True)
def handle_result(
    args: List[str], answer: str, target_window_id: int, boss: Boss
) -> None:
    parser = argparse.ArgumentParser(
        description="Open file over SSH session", add_help=False, exit_on_error=False
    )
    parser.add_argument(
        "action",
        choices=[
            "mpv_audio",
            "mpv_video",
            "pull",
            "push",
        ],
    )
    parser.add_argument("files", nargs="+")
    parser.add_argument("--cwd")
    parsed_args = None

    try:
        parsed_args = parser.parse_args(args[1:])
    except SystemExit:
        boss.show_error("Parse args failed", parser.format_help())
        return

    w = boss.window_id_map.get(target_window_id)
    conn_data = get_ssh_connection_data(w)
    if conn_data is None:
        boss.show_error(
            "Could not handle remote file",
            f"No SSH connection data found in: {args}",
        )
        return
    # print(conn_data)

    match parsed_args.action:
        case "mpv_audio":
            sftphost = (
                f"{conn_data.hostname}"
                if conn_data.port is None
                else f"{conn_data.hostname}:{conn_data.port}"
            )
            boss.call_remote_control(
                w,
                (
                    "launch",
                    "--type=tab",
                    "--title=remote",
                    # "--hold",  # for debug
                    MPV,
                    "--keep-open",
                    "--audio-display=no",
                    f"sftp://{sftphost}{parsed_args.files[0]}",
                    # *conn_data.cmd_prefix,
                    # conn_data.hostname,
                    # "cat",
                    # shlex.quote(parsed_args.files[0]),
                ),
            )
        case "mpv_video":
            sftphost = (
                f"{conn_data.hostname}"
                if conn_data.port is None
                else f"{conn_data.hostname}:{conn_data.port}"
            )
            subprocess.Popen(
                [
                    MPV,
                    "--keep-open",
                    "--no-terminal",
                    f"sftp://{sftphost}{parsed_args.files[0]}",
                ]
            )
        case "pull":
            boss.call_remote_control(
                w,
                (
                    "launch",
                    "--type=tab",
                    "--title=remote",
                    "--hold",
                    RSYNC_TOOL,
                    "--action",
                    "pull",
                    "--host",
                    conn_data.hostname,
                    *(["--port", str(conn_data.port)] if conn_data.port else []),
                    "--",
                    *parsed_args.files,
                ),
            )
        case "push":
            boss.call_remote_control(
                w,
                (
                    "launch",
                    "--type=tab",
                    "--title=remote",
                    "--hold",
                    RSYNC_TOOL,
                    "--action",
                    "push",
                    "--host",
                    conn_data.hostname,
                    *(["--port", str(conn_data.port)] if conn_data.port else []),
                    "--",
                    *parsed_args.files,
                ),
            )


class SSHConnectionData(NamedTuple):
    cmd_prefix: List[str]
    hostname: str
    port: Optional[int] = None


def is_proxy_jump_relay(cmdline: List[str]) -> bool:
    """是否是 ProxyJump（ssh -J）fork 出来的转发进程。

    OpenSSH 的 ProxyJump 实现就是在本地再起一个
    `ssh -W [target]:port jumphost`（ProxyCommand 形式也是它）。
    这个转发进程和真正的 ssh 在同一个前台进程组里，而且 pid 更大，
    而 kitty 的 Child.foreground_cmdline / pid_for_cwd 取的是前台进程组里
    pid 最大的那个（见 kitty/child.py: get_pid_for_cwd）。

    于是 get_connection_data() 解析到的是转发进程的命令行：`-W` 后面那个
    `[macmini.lan]:22` 被当成 -W 的取值吃掉，剩下的 `home.lubui.com`
    就变成了 hostname —— rsync 会去跳板机上拉 /Users/urie/...，
    在 Linux 跳板机上直接 change_dir 失败（push 更危险：会写到跳板机上）。
    """
    for arg in cmdline:
        if arg == "--":
            return False
        if arg == "-W" or (arg.startswith("-W") and len(arg) > 2):
            return True
    return False


def foreground_ssh_cmdlines(w) -> List[List[str]]:
    """前台进程组里的 ssh 命令行列表，新的进程排在前面。"""
    procs = sorted(
        w.child.foreground_processes or [], key=lambda p: p["pid"], reverse=True
    )
    cmdlines = []
    for proc in procs:
        cmdline = proc["cmdline"] or []
        if not cmdline:
            continue
        # 兜底判断，避免把同组的其他程序（比如脚本里的 vim）当成 ssh
        if os.path.basename(cmdline[0]).lower() not in ("ssh", "ssh.exe"):
            continue
        if is_proxy_jump_relay(cmdline):
            continue
        cmdlines.append(cmdline)
    return cmdlines


def get_ssh_connection_data(w):
    cmdlines = foreground_ssh_cmdlines(w)
    if w.ssh_kitten_cmdline():
        for ssh_cmdline in cmdlines:
            if "ControlPath=" not in " ".join(ssh_cmdline):
                continue
            if "--" not in ssh_cmdline:
                continue
            idx = ssh_cmdline.index("--")
            kitten_conn_data = ["!#*&$#($ssh-kitten)(##$"] + list(
                ssh_cmdline[: idx + 2]
            )
            hostname = kitten_conn_data[-1]
            sk_cmdline = kitten_conn_data[1:]
            while "-t" in sk_cmdline:
                sk_cmdline.remove("-t")
            cmd_prefix = sk_cmdline[:-2]
            port = None
            try:
                port = int(sk_cmdline[sk_cmdline.index("-p") + 1])
            except ValueError:
                pass
            return SSHConnectionData(cmd_prefix, hostname, port)

    cwd = w.child.foreground_cwd or w.child.current_cwd or ""
    for cmdline in cmdlines:
        conn_data = get_connection_data(cmdline, cwd)
        if conn_data is None:
            continue
        cmd_prefix = [
            conn_data.binary,
            "-o",
            "TCPKeepAlive=yes",
            "-o",
            "ControlPersist=yes",
        ]
        return SSHConnectionData(cmd_prefix, conn_data.hostname, conn_data.port)
    return None
