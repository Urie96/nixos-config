{ self, ... }:
{
  flake.wrappers.mitmproxy =
    {
      config,
      lib,
      ...
    }:
    let
      addonFiles = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".py" name) (
        builtins.readDir ./addons
      );
    in
    {
      imports = [
        self.wrapperModules.sops
      ];

      # confdir 用 module.nix 的默认值：$XDG_RUNTIME_DIR/<binName>（兜底 /tmp/<binName>）。
      # 想固定到某个目录再打开这行：
      # confdir = ".mitmproxy";

      # CA 私钥放在 sops 加密的 ./secrets.yaml 里（age recipient 见文件末尾），
      # 启动时渲染到 tmpfs；公开证书 assets/mitmproxy-ca-cert.pem 直接进 store。
      # 模板把「私钥占位符 + 公开证书」拼成 mitmproxy 需要的 mitmproxy-ca.pem（私钥+证书）。
      sops.secretsFile = ./secrets.yaml;
      sops.templates."mitmproxy-ca.pem".content =
        config.sops.placeholder.mitmproxy_ca_key + builtins.readFile "${self}/assets/mitmproxy-ca-cert.pem";

      ca = {
        pemFile = config.sops.templates."mitmproxy-ca.pem".path;
        certFile = "${self}/assets/mitmproxy-ca-cert.pem";
      };

      # mitmproxy 全局 option（键名见 `mitmproxy --options`），写进 <confdir>/config.yaml。
      settings = {
        scripts = [ "addons/addons.py" ];
        stream_large_bodies = "3m";
        validate_inbound_headers = false;
        # 命令历史会写 <confdir>/command_history；现在是 tmpfs，重启就没了。
        # 不想要就打开这行：
        # command_history = false;
      };

      # console 键位，编译成 <confdir>/keys.yaml（原来是手工维护的 keys.yaml）。
      # 字段：key / cmd 必填，ctx 空 = mitmproxy 默认 global。
      keybindings = [
        {
          key = "ctrl q";
          cmd = "console.exit";
        }
        {
          key = "c";
          ctx = [
            "flowlist"
            "flowview"
          ];
          cmd = "console.choose.cmd Format export.formats\nextra.osc_copy {choice} @focus\n";
        }
        {
          key = "F";
          ctx = [ "flowlist" ];
          cmd = "console.choose.cmd Action extra.filter_similar_options\nextra.filter_similar {choice}\n";
        }
        {
          key = "M";
          ctx = [
            "flowlist"
            "flowview"
          ];
          cmd = "console.choose.cmd Action extra.modify_later_options\nextra.modify_later {choice}\n";
        }
        {
          key = "t";
          ctx = [
            "flowlist"
            "flowview"
          ];
          cmd = "extra.test";
        }
        {
          key = "h";
          ctx = [ "flowlist" ];
          cmd = "console.choose.cmd Action extra.add_header_options\nextra.add_header_pre {choice}\n";
        }
        {
          key = "H";
          ctx = [ "flowlist" ];
          cmd = "console.command.set custom_env\n";
        }
        {
          key = "s";
          ctx = [
            "flowlist"
            "flowview"
          ];
          cmd = "extra.sse_stream_toggle";
        }
      ];

      # addons 还要软链进 confdir。
      confdirFiles = lib.mapAttrs' (
        name: _: lib.nameValuePair "addons/${name}" (./addons/${name})
      ) addonFiles;
    };
}
