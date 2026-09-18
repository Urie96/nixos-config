from kittens.tui.handler import result_handler
from typing import List
from kitty.boss import Boss
from kitty.tabs import Tab
from kitty.window import Window


def main(args: List[str]):
    pass


@result_handler(no_ui=True)
def handle_result(args: List[str], _: str, target_window_id: int, boss: Boss) -> None:
    window = boss.window_id_map.get(target_window_id)
    tab = boss.active_tab

    if not tab or not window:
        return

    orig_layout = tab.current_layout
    layout_changed = False
    candicates_tab_ids = tab.all_window_ids_except_active_window

    if orig_layout != "grid" and len(candicates_tab_ids) >= 2:
        layout_changed = True
        tab.goto_layout("grid")

    def callback(tab: Tab | None, window: Window | None) -> None:
        if tab and window:
            tab.set_active_window(window)
            if layout_changed:
                tab.goto_layout(orig_layout.name)

    boss.visual_window_select_action(
        tab,
        callback,
        "Choose window to switch to",
        only_window_ids=tab.all_window_ids_except_active_window,
    )
