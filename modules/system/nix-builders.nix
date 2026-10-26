{ self, ... }:
# 远程 builder 派发：aarch64-linux 交给 orangepi5plus，aarch64-darwin 交给 mac-mini，
# x86_64-linux 由 home-server 自己编（本机始终是隐式的本地 builder）。
#
# 为什么不用 clan 的 `deploy.buildHost`：那是「把这次 nixos-rebuild 挪到另一台机器上
# 执行」，每台机器只能指定一个，且要求架构与目标一致；这里要的是 nix daemon 级别的
# 跨架构派发（`nix.buildMachines`）。clan-core 目前没有对应模块，所以这里自己写，
# 但只用到 nixpkgs 的标准选项 + clan vars，跟 modules/services/cache-push.nix 的 ssh-ng
# 用法正好互为镜像（那边是推 store，这边是拉 builder）。
let
  keyName = "nix-builder-ssh";
  privateFile = "${keyName}.key";
  publicFile = "${keyName}.pub";

  # builder 侧的 ssh 用户：直接用 root。
  #
  # 不自己建账号的理由：builder 侧这个账号无论如何都得在 nix.settings.trusted-users
  # 里（ssh-ng 要把输入闭包写进对方 store），所以换账号并不会降权；真正的闸门是
  # 下面 authorized_keys 里的 restrict + forced command，跟账号是谁无关。而在 macOS
  # 上建账号还要走 sysadminctl + 唯一的 uid/gid 分配（撞号就 eDSRecordAlreadyExists，
  # 还会留下空记录把激活卡死），运维成本远高于收益。root 本来就在 trusted-users 里，
  # clan 部署本来也是以 root 登录，所以只需要往 root 的 authorized_keys 里加一行。
  #
  # 代价说明：万一哪天这行 authorized_keys 的 `restrict,command=...` 被写坏或删掉，
  # 这把 key 就从「只能说 store 协议」变成「root 可登录」，比专用账号的同类失误严重。
  # 另外 builder 日志里远程构建会显示成 root，和 clan 部署混在一起。
  builderUser = "root";

  # builder 访问 key。share = true：三台机器共用同一把 —— orangepi5plus / mac-mini
  # 把它写进 root 的 authorized_keys，home-server 的 nix daemon（以 root 跑）用它登录。
  #
  # 为什么必须是 root 有 key：`nix.buildMachines` 的 ssh 是由本机 nix daemon 发起的，
  # 不是 urie 的 shell，所以 `~/.ssh/id_ed25519` 用不上（root 也读不了别人的私钥，
  # ssh 会按 st_uid 拒绝）。
  #
  # 代价：import 本模块的机器都会拿到这把私钥。防御靠 authorized_keys 里的
  # restrict + command —— 用这把 key 登录后只能跑 nix daemon 的 ssh-ng 协议，
  # 没有 shell，也不能转发端口/agent。
  accessKey =
    { pkgs, ... }:
    {
      clan.core.vars.generators.${keyName} = {
        share = true;
        files.${privateFile} = { };
        files.${publicFile}.secret = false;
        runtimeInputs = [ pkgs.openssh ];
        script = ''
          ssh-keygen -q -t ed25519 -N "" -C ${keyName} -f "$out/${privateFile}"
          mv "$out/${privateFile}.pub" "$out/${publicFile}"
        '';
      };
    };

  # 公钥在求值期从 vars/ 里读（.value），和 cache-push 取自己的公钥是同一个套路，
  # 所以新生成器第一次用之前要先 `clan vars generate`。
  restrictedKey =
    lib: config:
    let
      pubKey = lib.trim config.clan.core.vars.generators.${keyName}.files.${publicFile}.value;
    in
    ''restrict,command="${config.nix.package}/bin/nix-daemon --stdio" ${pubKey}'';
in
{
  # ── builder 侧 ────────────────────────────────────────────────────────
  flake.nixosModules.nix-builders-builder =
    { config, lib, ... }:
    {
      imports = [ accessKey ];

      # clan 的 sshd 服务已经在维护 root 的 authorized_keys（inventory 里的
      # roles.server.settings.authorizedKeys），这里是列表合并，不会覆盖它们。
      users.users.root.openssh.authorizedKeys.keys = [ (restrictedKey lib config) ];
    };

  flake.darwinModules.nix-builders-builder =
    { config, lib, ... }:
    {
      imports = [ accessKey ];

      # 不碰 sysadminctl / uid-gid 分配，只往 root 的 authorized_keys 里加一行：
      # nix-darwin 会写到 /etc/ssh/nix_authorized_keys.d/root，由 sshd_config.d 里的
      # AuthorizedKeysCommand 生效，不动 /var/root/.ssh/authorized_keys。
      #
      # 不要把它登记进 users.knownUsers：那样 nix-darwin 会当成本机管理账号去改它。
      # uid/gid 只有在这条定义被其它模块 merge 时才是必填项，这里给 root 的 0/0。
      users.users.root = {
        uid = 0;
        gid = 0;
        openssh.authorizedKeys.keys = [ (restrictedKey lib config) ];
      };
    };

  # ── client 侧（home-server）───────────────────────────────────────────
  flake.nixosModules.nix-builders-client =
    { config, ... }:
    let
      sshKey = config.clan.core.vars.generators.${keyName}.files.${privateFile}.path;
    in
    {
      imports = [ accessKey ];

      nix.distributedBuilds = true;

      # protocol 必须是 ssh-ng：authorized_keys 里的 forced command 写死了
      # `nix-daemon --stdio`，旧的 `ssh` 协议会跑 `nix-store --serve` 而对不上。
      nix.buildMachines = [
        {
          # RK3588，8 核 / 7G。原生 aarch64-linux，替代之前注释掉的 qemu binfmt。
          hostName = "orangepi5plus.lan";
          sshUser = builderUser;
          inherit sshKey;
          protocol = "ssh-ng";
          systems = [ "aarch64-linux" ];
          maxJobs = 6;
          speedFactor = 2;
          # 有 /dev/kvm，所以 kvm / nixos-test 也能真派过去。
          supportedFeatures = [
            "big-parallel"
            "benchmark"
            "kvm"
            "nixos-test"
            "uid-range"
          ];
        }
        {
          # M 系列，8 核 / 8G。只能原生编 aarch64-darwin；aarch64-linux 要靠
          # nix.linux-builder 的 VM，而且那个 VM 只监听 127.0.0.1:31022，跨机器用不了。
          hostName = "macmini.lan";
          sshUser = builderUser;
          inherit sshKey;
          protocol = "ssh-ng";
          systems = [ "aarch64-darwin" ];
          maxJobs = 4;
          speedFactor = 3;
          supportedFeatures = [
            "big-parallel"
            "benchmark"
          ];
        }
      ];

      # 主机公钥校验：orangepi5plus 走了 clan 的 sshd 服务，证书由共享 CA 签发给
      # `<machine>.lan`，home-server 的 /etc/ssh/ssh_known_hosts 里已有
      # `@cert-authority *.lan`，不用额外声明。mac-mini 是 darwin、不参与该服务，
      # 没有证书，这里钉死它的 ed25519 host key（重装系统后要更新这行）。
      programs.ssh.knownHosts.macmini = {
        hostNames = [
          "macmini.lan"
          "192.168.2.2"
        ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGqNUf+y2y3uD+HbjS8PZQW9HsIgbgea2uIqyy+3GJrb";
      };
    };
}
