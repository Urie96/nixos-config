from quick_filters import QuickFilters
from osc52_copy import Osc52Copy
from modify_for_later import ModifyForLater
from add_header import AddHeader
from custom_env import CustomEnv
from sse_stream import SseStream

addons = [
    QuickFilters(),
    Osc52Copy(),
    ModifyForLater(),
    AddHeader(),
    CustomEnv(),
    SseStream(),
]
