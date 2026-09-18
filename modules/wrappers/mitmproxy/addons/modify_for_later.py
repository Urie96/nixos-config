import logging
from collections.abc import Sequence

from mitmproxy import command, ctx, http
from mitmproxy.log import ALERT


class ModifyForLater:
    def __init__(self):
        self.modify_request_map = dict()
        self.modify_response_map = dict()

    def request(self, flow):
        if not isinstance(flow, http.HTTPFlow):
            return
        key = flow.request.method + flow.request.url
        modify_to = self.modify_request_map.get(key)
        if modify_to:
            flow.request.headers = modify_to.get("headers")
            flow.request.set_text(modify_to.get("body"))
            logging.log(ALERT, "request modified")

    def response(self, flow):
        if not isinstance(flow, http.HTTPFlow) or flow.response is None:
            return
        key = flow.request.method + flow.request.url
        modify_to = self.modify_response_map.get(key)
        if modify_to:
            flow.response.headers = modify_to.get("headers")
            flow.response.set_text(modify_to.get("body"))
            logging.log(ALERT, "response modified")

    @command.command("extra.modify_later_options")
    def modify_for_later_options(self) -> Sequence[str]:
        return [
            "modify later response",
            "modify later request",
            "clear all",
        ]

    @command.command("extra.modify_later")
    def modify_for_later(self, action: str) -> None:
        options = self.modify_for_later_options()
        if action == options[2]:
            self.modify_response_map.clear()
            self.modify_request_map.clear()
            return
        view = ctx.master.addons.get("view")
        if view is None:
            return
        flow = view.focus.flow
        key = flow.request.method + flow.request.url
        if action == options[0]:
            self.modify_response_map[key] = {
                "headers": flow.response.headers,
                "body": flow.response.get_text(),
            }
        elif action == options[1]:
            self.modify_request_map[key] = {
                "headers": flow.request.headers,
                "body": flow.request.get_text(),
            }
