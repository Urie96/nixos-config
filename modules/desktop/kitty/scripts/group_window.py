from kittens.tui.handler import result_handler
from typing import List
from kitty.boss import Boss


def main(args: List[str]):
    pass


@result_handler(no_ui=True)
def handle_result(args: List[str], _: str, target_window_id: int, boss: Boss) -> None:
    window = boss.window_id_map.get(target_window_id)
    if not window:
        return

    group_name = args[1]

    match_tab = [tab for tab in boss.all_tabs if tab.name == group_name]

    if len(match_tab) > 0:
        tab = match_tab[0]
        if tab.id != window.tab_id:
            boss._move_window_to(window, target_tab_id=tab.id)
    else:
        current_tab = boss.tab_for_id(window.tab_id)
        if not current_tab:
            return

        if len(current_tab.windows) > 1:
            boss._move_window_to(window, target_tab_id="new")
            new_tab = boss.tab_for_id(window.tab_id)
            if new_tab:
                new_tab.set_title(group_name)
        else:
            current_tab.set_title(group_name)
