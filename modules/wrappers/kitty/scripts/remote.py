import argparse
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


def get_ssh_connection_data(w):
    args = w.ssh_kitten_cmdline()
    if args:
        ssh_cmdline = sorted(w.child.foreground_processes, key=lambda p: p["pid"])[-1][
            "cmdline"
        ] or [""]
        if "ControlPath=" in " ".join(ssh_cmdline):
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

    args = w.child.foreground_cmdline
    conn_data = get_connection_data(
        args, w.child.foreground_cwd or w.child.current_cwd or ""
    )
    if conn_data is None:
        return None
    cmd_prefix = [
        conn_data.binary,
        "-o",
        "TCPKeepAlive=yes",
        "-o",
        "ControlPersist=yes",
    ]
    return SSHConnectionData(cmd_prefix, conn_data.hostname, conn_data.port)
