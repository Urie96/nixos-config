{
  flake.nixosModules.catppuccin =
    {
      config,
      self,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [
        self.inputs.catppuccin-nix.nixosModules.catppuccin
      ];

      catppuccin = {
        enable = true;
        autoEnable = true;
        flavor = "mocha";

        # 所有平台关掉 tty 端口：catppuccin-nix 的 tty 模块在求值期用
        # `lib.importJSON "${sources.palette}/palette.json"` 读 palette（IFD），
        # 会让 eval nixosConfigurations 时去构建 catppuccin-palette（依赖 whiskers），
        # 在 aarch64 目标上就是本地 qemu 模拟编译整套 Rust。
        # 顺带效果：console.colors 不再用 catppuccin 配色，回 NixOS 默认。
        tty.enable = false;
      };
    };

}
