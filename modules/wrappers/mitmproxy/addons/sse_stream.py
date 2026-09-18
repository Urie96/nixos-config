import logging

from mitmproxy import command, ctx, http
from mitmproxy.log import ALERT


class SseStream:
    def load(self, loader):
        loader.add_option(
            name="sse_stream_toggle",
            typespec=bool,
            default=False,
            help="Treat all SSE responses as streaming",
        )
        logging.log(ALERT, "SSE streaming toggle: OFF")

    @command.command("extra.sse_stream_toggle")
    def toggle_sse_stream(self) -> None:
        current = ctx.options.sse_stream_toggle
        ctx.options.sse_stream_toggle = not current
        status = "ON" if ctx.options.sse_stream_toggle else "OFF"
        logging.log(ALERT, f"SSE streaming toggle: {status}")

    @staticmethod
    def is_sse(flow: http.HTTPFlow) -> bool:
        return flow.response.headers.get("content-type", "").startswith(
            "text/event-stream"
        )

    def responseheaders(self, flow: http.HTTPFlow) -> None:
        if ctx.options.sse_stream_toggle and self.is_sse(flow):
            flow.response.stream = True
