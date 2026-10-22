{
  inputs,
  lib,
  ...
}:
let
  # 固定到 old-nixpkgs 的包名单（顶层属性名）。要加新包只改这个列表。
  #
  # 整包替换而不是 override：这些包一般带一整套运行时闭包（Python 应用是
  # python + 依赖，yazi 带 shared libs），新旧 nixpkgs 混搭会在加载阶段炸掉，
  # 所以包本身必须整体来自 old-nixpkgs。
  #
  # 被固定的包在 old-nixpkgs 里必须对每个目标平台都存在
  # （x86_64-linux / aarch64-linux / aarch64-darwin），否则求值会直接报错。
  pinnedPackages = [
    "todoman"
    "yazi"
  ];

  # 只替换这几个属性，pre/post 都取当前 nixpkgs 的对应包，
  # 避免跨 nixpkgs 版本引用闭包。
  pinFromOldNixpkgs =
    prev:
    let
      old = inputs.old-nixpkgs.legacyPackages.${prev.stdenv.hostPlatform.system};
    in
    lib.genAttrs pinnedPackages (name: old.${name});
in
{
  flake.overlays.old-packages = _final: prev: pinFromOldNixpkgs prev;

  # 不要在这里导出 `packages.<name>`：nix-wrapper-modules 已经把每个 wrapper
  # 暴露成 `packages.<name>`（如 packages.todoman / packages.yazi），
  # 重复定义会报 "defined multiple times"。
  # 验证：`nix build .#todoman`、`nix build .#yazi`。
}
