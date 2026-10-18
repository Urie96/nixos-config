{ ... }:
let
  # 构建签名 key 的名字。这个名字和私钥一起写进 store 的签名信息，客户端看到的是
  # "<name>:<sig>"，所以改名等于换 key（要同步所有机器的 trusted-public-keys）。
  #
  # 与 harmonia 的旧缓存 key（cache.lubui.com-2）不是同一把：harmonia 现在两把都用
  # （narinfo 会带两行 Sig:，客户端信任意一把都行），过渡完成后可以只留这把，
  # 把 -2 和它的 generator 一起删掉。
  signingKeyName = "cache.lubui.com-1";

  # 本机构建的包自动签名（secret-key-files 是 daemon 级设置），同时定义这把共享的
  # 签名密钥。
  #
  # 为什么需要：orangepi5plus / mac-mini 的产物要 `nix copy` 推到 home-server 的
  # store，而那里开了 require-sigs，未签名的路径会被拒绝。在构建时就签好，比事后
  # `nix store sign` 省事，也不用给构建机额外的权限。
  #
  # generator 用 share = true：三台构建机声明同一个 generator，只生成一次、共用一把
  # key，签名才互相认。公钥要出现在所有消费该缓存的机器的 trusted-public-keys 里
  # （modules/system/nix-daemon.nix）。
  #
  # 注意：share 决定值存在 vars/per-machine/<machine>/<gen> 还是 vars/shared/<gen>。
  # 改 share 不会搬文件，旧值留在原处会被忽略并生成一把新 key（所有已签名路径失效），
  # 迁移必须先 `clan vars get` 再 `clan vars set`。
  #
  # 代价：开启它的机器上任何构建（不只 runner 起的）都会带签名。签名只说明「这个
  # NAR 是在持有这把 key 的机器上构建的」，不是内容可信的背书；客户端是按 hash
  # 取路径的，缓存替换不了已有包的内容。
  signing =
    { config, pkgs, ... }:
    {
      # 同一台机器上 harmonia / cache-push / 机器自己都可能 import 本模块。没有 key 时
      # 每处 import 都是一个独立模块实例，list 型设置会叠加成
      # `secret-key-files = <path> <path> <path>`；显式 key 让模块系统按 key 去重。
      key = "nix-signing";

      clan.core.vars.generators.nix-signing = {
        share = true;
        files."nix-signing.secret" = { };
        files."nix-signing.pub".secret = false;
        runtimeInputs = with pkgs; [ nix ];
        script = ''
          nix-store --generate-binary-cache-key ${signingKeyName} $out/nix-signing.secret $out/nix-signing.pub
        '';
      };

      nix.settings.secret-key-files = [
        config.clan.core.vars.generators.nix-signing.files."nix-signing.secret".path
      ];
    };
in
{
  flake.nixosModules.nix-signing = signing;
  flake.darwinModules.nix-signing = signing;
}
