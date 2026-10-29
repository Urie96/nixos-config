{ self, withSystem, ... }:
# CI 入口：`nix run .#ci` 一条命令构建所有整机配置，并打印总闭包体积 + 各配置的体积。
#
# 为什么脚本写在 nix 里而不是 workflow 里：机器清单、attr 名字、以及「哪些架构靠远程
# builder 派发」都是 nix 侧的知识。workflow 只负责 `nix run .#ci`，以后加机器 / 改输出
# 只要动这个文件，YAML 不用跟着改。
let
  nixos = name: self.nixosConfigurations.${name}.config.system.build.toplevel;
  darwin = name: self.darwinConfigurations.${name}.config.system.build.toplevel;
  # system-manager（modules/machines/devbox.nix），本身就是一个 derivation
  systemManager = system: name: self.legacyPackages.${system}.systemConfigs.${name};
  # nix-on-droid（modules/machines/nix-on-droid.nix）
  nixOnDroid =
    name: self.legacyPackages.aarch64-linux.nixOnDroidConfigurations.${name}.activationPackage;

  # 唯一的 source of truth：列出的就是进 CI 的整机配置，想排除某台机器删掉一行即可
  # （不会自动从 nixosConfigurations 抓全量）。不按 system 分组 —— 谁能构建哪台由
  # builder 配置决定，而不是由表的结构决定。
  targets = {
    home-server = nixos "home-server";
    nixos-desktop = nixos "nixos-desktop";
    tencent-cloud-korea = nixos "tencent-cloud-korea";
    devbox = systemManager "x86_64-linux" "devbox";

    orangepi5plus = nixos "orangepi5plus";
    rpi4 = nixos "rpi4";
    nix-on-droid = nixOnDroid "default";

    mac-mini = darwin "mac-mini";
    work-macbook = darwin "work-macbook";
  };

  # 聚合产物名：`.#ci-all`。脚本里的引用由这个变量生成，避免两处手写不一致。
  aggregate = "ci-all";

  # 注意：`packages.ci-all` 只是一个 linkFarm，条目是指向各架构 toplevel 的符号链接，
  # 自身在本地秒建（preferLocalBuild）；被链接的 toplevel 才是真正的构建目标，跨架构的
  # 由 nix.buildMachines 派发（aarch64-linux → orangepi5plus，aarch64-darwin → macmini）。
  #
  # 只在 x86_64-linux 下定义：linkFarm 由宿主 pkgs 生成，在 darwin 上求值会得到本机建不了
  # 的 drv，而 CI 也只在 home-server 上跑。
in
{
  flake.packages.x86_64-linux = withSystem "x86_64-linux" (
    { pkgs, ... }:
    {
      ${aggregate} = pkgs.linkFarm aggregate targets;

      ci = pkgs.writeShellApplication {
        name = "ci";
        runtimeInputs = [
          pkgs.nix
          pkgs.coreutils
        ];
        meta.mainProgram = "ci";
        # `nix run .#ci` 要在仓库根目录下执行：脚本里的 `.#` 指的就是当前目录的 flake。
        text = ''
          if ! out=$(nix build --keep-going -L --no-link --print-out-paths ".#${aggregate}"); then
            echo "build failed: see the per-derivation logs above" >&2
            exit 1
          fi

          echo
          echo "### total closure size (all machines, all systems)"
          nix path-info -Sh "$out"
          echo
          echo "### closure size per configuration"
          for path in "$out"/*; do
            # 条目是指向各机器 toplevel 的符号链接；`nix path-info` 拿到非 store 路径会
            # 当 flake 去解析，所以先 readlink 成真正的 store path。
            real=$(readlink -f "$path")
            read -r _ size unit <<<"$(nix path-info -Sh "$real")"
            printf '%-20s %s %s\n' "''${path##*/}" "$size" "$unit"
          done
        '';
      };
    }
  );
}
