{ withSystem, ... }:
{
  # https://search.nixos.org/options?channel=unstable
  flake.nixosModules.common =
    {
      config,
      self,
      lib,
      pkgs,
      ...
    }:
    let
      partsArgs = withSystem config.nixpkgs.hostPlatform.system (args: args);

      # 证书用相对路径 + builtins.path 变成独立 store path，避免 "${self}/..."
      # 把整个仓库源码拖进系统闭包（否则每次 commit 都会改变闭包 hash，
      # 闭包里还多一份源码拷贝）。
      mitmproxyCaCert = builtins.path {
        path = ../wrappers/mitmproxy/mitmproxy-ca-cert.pem;
        name = "mitmproxy-ca-cert.pem";
      };
    in
    {
      imports = [
        self.inputs.srvos.nixosModules.common
        self.inputs.srvos.nixosModules.mixins-nix-experimental
        self.inputs.srvos.nixosModules.mixins-trusted-nix-caches
      ];

      _module.args = { inherit (partsArgs) self' inputs'; };

      boot.kernel = {
        sysctl = {
          "net.ipv4.conf.all.forwarding" = true;
        };
      };

      environment.variables = {
        EDITOR = lib.mkForce "nvim";
        MANPAGER = "nvim +Man!";
        HF_ENDPOINT = "https://hf-mirror.com";
      };

      documentation = {
        info.enable = false;
        nixos.enable = lib.mkForce false;
        doc.enable = false;
      };

      security.pki.certificateFiles = [ mitmproxyCaCert ];

      time.timeZone = "Asia/Shanghai";

      # Use memory more efficiently at the cost of some compute
      zramSwap.enable = true;

      console.earlySetup = true;

      services.openssh.enable = true;

      programs = {
        nano.enable = false;
        nix-ld.enable = true;
        mosh.enable = true;
        # direnv = {
        #   enable = true;
        #   nix-direnv.enable = true;
        # };
      };

      security.sudo.wheelNeedsPassword = false; # sudo without password
      programs.command-not-found.enable = false;

      i18n.defaultLocale = "zh_CN.UTF-8";
      i18n.supportedLocales = [
        "zh_CN.UTF-8/UTF-8"
        "en_US.UTF-8/UTF-8"
      ];

      environment.systemPackages = with pkgs; [
        kitty.terminfo
        lm_sensors
      ];
    };

}
