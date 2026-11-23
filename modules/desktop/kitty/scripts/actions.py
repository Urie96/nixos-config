from typing import List
from kitty.boss import Boss, Window
from functools import partial
from kittens.tui.handler import result_handler
from kittens.tui.operations import styled

# https://sw.kovidgoyal.net/kitty/kittens/custom/


def main(args: List[str]):
    pass


@result_handler(no_ui=True)
def handle_result(args: List[str], _: str, target_window_id: int, boss: Boss) -> None:
    # get the kitty window into which to paste answer
    w = boss.window_id_map.get(target_window_id)
    if w is None:
        return
    boss.choose(
        "What would you like to do with kitty:\n",
        partial(cb, boss, w),
        "r:Reload config file",
        "h:h:Lazydeck process",
        "i:i:Scroll up prompt",
        "s:Kitty shell",
        "t:t:Quick Actions",
        "n:Daily Note",
        # "n;red:Nothing",
        window=w,
    )


def cb(boss: Boss, window: Window, o: str):
    match o:
        case "s":
            boss.kitty_shell()
        case "i":
            if boss.active_window:
                boss.active_window.scroll_to_prompt(-1)
        case "r":
            boss.load_config_file()
        case "t":
            boss.launch("--type=tab", "--title=Action", "t")
        case "n":
            boss.launch("--type=tab", "--title=Daily Note", "zk", "d")
        case "h":
            pid = window.child.pid_for_cwd
            if not pid:
                boss.show_error("Kill failed", "pid is None")
                return

            boss.launch("--type=overlay", "lazydeck", "/process/" + str(pid))
        case _:
            pass
