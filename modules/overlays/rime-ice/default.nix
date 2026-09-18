{
  flake.overlays.rime-ice = _final: prev: {
    rime-ice = prev.rime-ice.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./emoji.patch ];

      # ./custom 里的个人配置（default.custom.yaml、squirrel.custom.yaml 等）
      # 一并装进 $out/share/rime-data，dotfiles 只需链接这一个目录到
      # ~/.config/rime，就能同时拿到雾凇数据和个人覆盖。
      postInstall = (old.postInstall or "") + ''
        cp -r ${./custom}/. $out/share/rime-data/
      '';
    });
  };

  perSystem = { pkgs, ... }: {
    # flake.nix 里的 perSystem pkgs 已经叠了 self.overlays.rime-ice，
    # 这里直接取用即可，不要再 overrideAttrs 一次（会重复打补丁）。
    packages.rime-ice = pkgs.rime-ice;
  };
}
