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

  # builder 上的专用账号：只用来接 ssh-ng store 协议，不给 shell 之外的任何东西
  # （NixOS 上是 isSystemUser，darwin 上是 hidden + /bin/bash）。
  #
  # 不用 urie 的原因：那样 builder 访问权就跟人的账号绑在一起 —— 轮换 urie 的
  # 公钥、改它的 groups/shell、或者干脆把 urie 从 wheel 里挪走，都会连带影响构建；
  # 反过来看 daemon 日志时也分不清「远程构建」和「我自己登录」。
  # 注意这换不来更小的 store 权限：builder 侧这个账号仍然必须在
  # nix.settings.trusted-users 里（否则 ssh-ng 没法把输入路径写进对方 store），
  # 所以收益是解耦 + 可审计，不是降权。钥匙本身的限制仍然是下面的 forced command。
  builderUser = "nix-builder";

  # builder 访问 key。share = true：三台机器共用同一把 —— orangepi5plus / mac-mini
  # 把它写进 nix-builder 的 authorized_keys，home-server 的 nix daemon（以 root 跑）
  # 用它登录。
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
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ accessKey ];

      # 组不能是 nixbld（daemon 会拒），shell 也不能是 nologin（sshd 用用户 shell
      # 执行 authorized_keys 里的 forced command），和 cache-push 的约束一样。
      users.groups.${builderUser} = { };
      users.users.${builderUser} = {
        isSystemUser = true;
        group = builderUser;
        shell = pkgs.bash;
        openssh.authorizedKeys.keys = [ (restrictedKey lib config) ];
      };

      # ssh-ng 会把输入的闭包写进本机 store，非 trusted 用户会被签名检查拦下来。
      nix.settings.trusted-users = [ builderUser ];
    };

  flake.darwinModules.nix-builders-builder =
    { config, lib, ... }:
    {
      imports = [ accessKey ];

      # nix-darwin 只会创建 knownUsers / knownGroups 里列出的账号；uid/gid 挑一个
      # 本机没被占用的（_nixbld* 是 350-382，urie 是 501）。
      users.knownGroups = [ builderUser ];
      users.knownUsers = [ builderUser ];
      users.groups.${builderUser} = { gid = 400; };
      users.users.${builderUser} = {
        uid = 400;
        gid = 400;
        home = "/var/empty";
        # 默认 shell 是 /usr/bin/false，那样 forced command 根本不会被执行，
        # 表现成「Permission denied」而不是能看懂的报错，所以必须显式给 bash。
        shell = "/bin/bash";
        isHidden = true;
        # nix-darwin 会把这些 key 落到 /etc/ssh/nix_authorized_keys.d/<user>，
        # 通过 sshd_config.d 里的 AuthorizedKeysCommand 生效，不动 ~/.ssh/authorized_keys。
        openssh.authorizedKeys.keys = [ (restrictedKey lib config) ];
      };

      nix.settings.trusted-users = [ builderUser ];
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
