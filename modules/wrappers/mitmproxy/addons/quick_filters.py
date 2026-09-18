import logging
from collections.abc import Sequence
from mitmproxy import command, ctx, http
from mitmproxy.log import ALERT


def split_url(flow: http.HTTPFlow):
    host = flow.request.host
    path, *query = flow.request.path.split("?", 1)
    query = query[0] if len(query) > 0 else ""
    return host, path, query


class QuickFilters:
    def __init__(self):
        self.filters = []

    @command.command("extra.filter_similar_options")
    def filter_url_options(self) -> Sequence[str]:
        return [
            "only show this host",
            "only show this url",
            "hide this host",
            "hide this url",
            "clear filter",
        ]

    @command.command("extra.filter_similar")
    def filter_url(self, action: str) -> None:
        options = self.filter_url_options()
        if action == options[4]:
            self.filters.clear()
            ctx.master.commands.call("set", "view_filter", "")
            logging.log(ALERT, "clear")
            return

        if len(self.filters) == 0 and ctx.master.options.view_filter:
            self.filters.append("(" + ctx.master.options.view_filter + ")")

        view = ctx.master.addons.get("view")
        if view is None:
            return
        flow = view.focus.flow
        host, path, _ = split_url(flow)

        if action == options[0]:
            self.filters.append(f"~u {host}")
        elif action == options[1]:
            self.filters.append(f"~u {host+path}")
        elif action == options[2]:
            self.filters.append(f"!(~u {host})")
        elif action == options[3]:
            self.filters.append(f"!(~u {host+path})")
        ctx.master.commands.call("set", "view_filter", " & ".join(self.filters))
        logging.log(ALERT, "done")
