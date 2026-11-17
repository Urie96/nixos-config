let
  make-singbox-var =
    {
      remote_ip,
      remote_domain,
      name,
    }:
    { pkgs, ... }:
    {
      clan.core.vars.generators.${name} = {
        share = true;
        files = {
          "key".owner = "sing-box";
          "crt".secret = false;
          "uuid".owner = "sing-box";
          "remote_ip".secret = false;
          "remote_domain".secret = false;
        };
        runtimeInputs = with pkgs; [
          openssl
          python3
        ];
        script = ''
          echo -n ${remote_ip} > $out/remote_ip
          echo -n ${remote_domain} > $out/remote_domain

          # sys.stdout.write 而不是 print：值后面不能带换行。
          # uuid 会被直接插进分享链接（dae 的 node 链接、sing-box 的 _secret），
          # 带 \n 的话 url 解析会报 invalid control character。
          python3 -c "import sys, uuid; sys.stdout.write(str(uuid.uuid4()))" > $out/uuid

          openssl req -x509 -newkey rsa:2048 -nodes \
            -keyout $out/key \
            -out $out/crt \
            -days 3650 \
            -subj "/CN=${remote_domain}" \
            -addext "subjectAltName=DNS:${remote_domain},IP:${remote_ip}"
        '';
      };
    };

  # REALITY 的服务端只需要一对 X25519 密钥 + short_id，客户端拿到同一个
  # public_key / short_id。handshake_domain 也一起放进 vars：它必须两端一致
  # （客户端把它当 SNI 发），放一处免得两边写法漂移。
  make-singbox-reality-var =
    {
      name,
      handshake_domain,
    }:
    { pkgs, ... }:
    {
      clan.core.vars.generators.${name} = {
        share = true;
        files = {
          "private_key".owner = "sing-box";
          "public_key".secret = false;
          "short_id".secret = false;
          "handshake_domain".secret = false;
        };
        runtimeInputs = with pkgs; [
          sing-box
          openssl
          gnused
        ];
        script = ''
          keypair=$(sing-box generate reality-keypair)
          printf '%s' "$keypair" | sed -n 's/^PrivateKey: //p' > $out/private_key
          printf '%s' "$keypair" | sed -n 's/^PublicKey: //p' > $out/public_key

          # 8 字节 short_id（16 个 hex 字符），两端必须一致
          openssl rand -hex 8 | tr -d '\n' > $out/short_id

          echo -n ${handshake_domain} > $out/handshake_domain
        '';
      };
    };

  singbox-kr-var = make-singbox-var {
    remote_domain = "kr.lubui.buzz";
    remote_ip = "43.166.24.118";
    name = "sing-box-kr";
  };
  singbox-kr-config = import ./_make-oversea.nix "sing-box-kr";

  # 握手目标：从 KR 实测 TLS1.3 + h2 都正常，TCP RTT ~7ms（微软在韩国有 POP）。
  # 换站点时只要改这一行，然后重新生成 vars + 重新部署两端。
  singbox-kr-reality-var = make-singbox-reality-var {
    name = "sing-box-kr-reality";
    handshake_domain = "www.microsoft.com";
  };
  singbox-kr-reality-config = import ./_make-reality.nix {
    name = "sing-box-kr-reality";
    uuidGenerator = "sing-box-kr";
  };

  # hysteria2 只需要两个密码（用户密码 + obfs salamander 密码），证书直接复用
  # sing-box-kr 那张自签证书。
  make-singbox-hysteria2-var =
    { name }:
    { pkgs, ... }:
    {
      clan.core.vars.generators.${name} = {
        share = true;
        files = {
          "password".owner = "sing-box";
          "obfs_password".owner = "sing-box";
        };
        runtimeInputs = with pkgs; [ openssl ];
        script = ''
          openssl rand -hex 16 > $out/password
          openssl rand -hex 16 > $out/obfs_password
        '';
      };
    };

  singbox-kr-hysteria2-var = make-singbox-hysteria2-var {
    name = "sing-box-kr-hysteria2";
  };
  singbox-kr-hysteria2-config = import ./_make-hysteria2.nix {
    name = "sing-box-kr-hysteria2";
    certFrom = "sing-box-kr";
  };

  singbox-hk-var = make-singbox-var {
    remote_domain = "jp.lubui.buzz";
    remote_ip = "47.76.155.157";
    name = "sing-box-hk";
  };
  singbox-hk-config = import ./_make-oversea.nix "sing-box-hk";
in

{
  # home-server 不再跑 sing-box 客户端：全局网关那部分（tun-in + TUN 分流 +
  # clash_api）已经换成 dae，见 modules/services/dae/default.nix。
  # 这里只保留：
  #   * 上面那些 generator（Android 订阅和 dae 都要读同一份 vars）；
  #   * _android.nix —— 生成 sing-box for Android 的订阅配置并由 nginx 提供；
  #   * 服务端（singbox-kr / singbox-hk）不受影响，仍在各自 VPS 上跑。
  # 回滚：把 ./_home.nix 加回 imports，并在 home-server 上停用 dae-home。
  flake.nixosModules.singbox-home = {
    imports = [
      singbox-hk-var
      singbox-kr-var
      # dae（和 Android 订阅）要读 public_key / short_id / handshake_domain，
      # 所以同一份 generator 也要在这里声明（share = true，值来自 clan 共享的 vars）
      singbox-kr-reality-var
      singbox-kr-hysteria2-var
      # ./_home.nix
      ./_android.nix
    ];

    # 虽然 home-server 上 services.sing-box 已经关了，但上面这些 generator
    # 的 secret 文件 owner 仍然是 sing-box（share = true，两台 VPS 上的
    # sing-box 服务要读同一批文件）。sops-install-secrets 会用 user.Lookup
    # 校验 owner，用户不存在会让激活直接失败，所以这个用户得留着。
    # 属性与 nixpkgs sing-box 模块里的定义保持一致，回滚重开服务时不会冲突。
    users.users.sing-box = {
      isSystemUser = true;
      group = "sing-box";
      home = "/var/lib/sing-box";
    };
    users.groups.sing-box = { };
  };

  flake.nixosModules.singbox-kr = {
    imports = [
      singbox-kr-var
      singbox-kr-reality-var
      singbox-kr-hysteria2-var
      singbox-kr-config
      singbox-kr-reality-config
      singbox-kr-hysteria2-config
    ];
  };
  flake.nixosModules.singbox-hk = {
    imports = [
      singbox-hk-var
      singbox-hk-config
    ];
  };
}
