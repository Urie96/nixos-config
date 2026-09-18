from kittens.tui.handler import result_handler
from typing import List
from kitty.boss import Boss
from kitty.tabs import Tab
from kitty.tabs import EdgeLiteral


def main(args: List[str]):
    pass


@result_handler(no_ui=True)
def handle_result(args: List[str], _: str, target_window_id: int, boss: Boss) -> None:
    # get the kitty window into which to paste answer
    window = boss.window_id_map.get(target_window_id)
    tab = boss.active_tab

    if not tab or not window:
        return

    match args[1]:
        case "left":
            if active_neighbor_window(tab, "left"):
                return
            # elif boss.active_tab_manager:
            #     boss.active_tab_manager.next_tab(-1)
        case "right":
            if active_neighbor_window(tab, "right"):
                return
            # elif boss.active_tab_manager:
            #     boss.active_tab_manager.next_tab(1)
        case "top":
            active_neighbor_window(tab, "top")
        case "bottom":
            active_neighbor_window(tab, "bottom")
        case _:
            raise NotImplementedError


def active_neighbor_window(tab: Tab, direction: EdgeLiteral) -> bool:
    if not tab:
        return False
    if tab.current_layout.only_active_window_visible:
        return False
    neighbor = tab.neighboring_group_id(direction)
    if neighbor:
        tab.windows.set_active_group(neighbor)
        tab.neighboring_window(direction)
        return True
    return False
