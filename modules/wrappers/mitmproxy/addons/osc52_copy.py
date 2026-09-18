import logging
import base64

from mitmproxy import command, ctx, flow
from mitmproxy.log import ALERT


class Osc52Copy:
    @command.command("extra.osc_copy")
    def osc_copy(self, format: str, fl: flow.Flow) -> None:
        curl_str = ctx.master.commands.call("export", format, fl)
        print("\033]52;c;" + base64.b64encode(curl_str.encode()).decode() + "\007")
        logging.log(ALERT, f"{format} copied to system clipboard")
