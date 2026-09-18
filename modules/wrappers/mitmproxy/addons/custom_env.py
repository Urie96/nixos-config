import logging

from mitmproxy import ctx
from mitmproxy.log import ALERT


class CustomEnv:
    def load(self, loader):
        loader.add_option(
            name="custom_env",
            typespec=str,
            default="",
            help="Define env for request",
        )

    def request(self, flow):
        custom_env = ctx.options.custom_env
        if custom_env.startswith("ppe_"):
            flow.request.headers.pop("x-use-boe", None)
            flow.request.headers["x-use-ppe"] = "1"
            flow.request.headers["x-tt-env"] = custom_env
        elif custom_env.startswith("boe_"):
            flow.request.headers.pop("x-use-ppe", None)
            flow.request.headers["x-use-boe"] = "1"
            flow.request.headers["x-tt-env"] = custom_env
        elif custom_env != "":
            logging.log(ALERT, f"Unkown custom env: {custom_env}")
