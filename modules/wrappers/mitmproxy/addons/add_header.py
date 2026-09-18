import logging
from collections.abc import Sequence

from mitmproxy import command, ctx, http
from mitmproxy.log import ALERT


class AddHeader:
    def __init__(self):
        self.extra_headers = dict()

    def request(self, flow):
        if not isinstance(flow, http.HTTPFlow):
            return
        for key, val in self.extra_headers.items():
            flow.request.headers[key] = val

    @command.command("extra.add_header_options")
    def add_header_options(self) -> Sequence[str]:
        return [
            "set env",
            "add header",
            "clear added header",
        ]

    @command.command("extra.add_header")
    def add_header(self, key: str, value: str) -> None:
        self.extra_headers[key] = value
        logging.log(ALERT, f"Add Header({key}: {value})")

    @command.command("extra.add_header_pre")
    def add_header_pre(self, action: str) -> None:
        options = self.add_header_options()
        if action == options[0]:
            ctx.master.commands.call("console.command.set", "custom_env")
        elif action == options[1]:
            ctx.master.commands.call("console.command", "extra.add_header")
        elif action == options[2]:
            self.extra_headers.clear()
