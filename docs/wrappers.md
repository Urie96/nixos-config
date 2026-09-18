# 添加 wrapper

`modules/wrappers/<name>/` 里的每个 wrapper 导出 `flake.wrappers.<name>`，用 `nix build .#<name>` 构建。`import-tree` 自动导入 `modules/` 下的每个 `.nix`，不用在 `flake.nix` 注册。

优先用上游模块：`nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.wrappers.outPath'` 下的 `wrapperModules/<首字母>/<名字>/module.nix` 已有就直接 `imports = [ wlib.wrapperModules.<名字> ];`。通用选项（`env`、`flags`、`constructFiles`、`runtimePkgs`…）见同一份源码里的 `README.md` 和 `modules/makeWrapper/module.nix`。

## 布局

- `module.nix`：通用逻辑（`imports` / `options` / `config`），只用 `pkgs`、`wlib`，不含本机配置。
- `default.nix`：本仓库的配置（settings、路径、密钥来源）。
- 还要再拆就用别的 `.nix`：同一个 flake 输出会合并，所以任意文件都可以再定义一次 `flake.wrappers.<name>` 往同一个 wrapper 里加配置（`modules/wrappers/yazi/` 就是这么拆的）。
- 自建模块用 `wlib.modules.default`；只改配置时，`default.nix` 一个文件就够（参考 `modules/wrappers/tmux/default.nix`）。

## 步骤

### 1. 写 wrapper，最外层留外壳

每个文件的最外层是外壳：

```nix
{
  flake.wrappers.foo =
    { config, lib, wlib, pkgs, ... }:
    {
      imports = [ wlib.modules.default ];

      options = { ... };

      config = {
        package = lib.mkDefault pkgs.foo;
        ...
      };
    };
}
```

外壳缺席——例如把 wrapper 模块（`imports = [ wlib.modules.default ];` 加选项）直接挂在 flake-parts 顶层——会变成无限递归，报错指向 `wlib`、`config`、`imports` 这几个词。看到这个组合先回来检查外壳在不在。

需要生成配置文件时，把它写进 wrapper 自己的输出，再用 `env` 指过去：

- `constructFiles.<file> = { relPath = "${config.binName}config"; content = …; };`
- 引用时用 `config.constructFiles.<file>.path`（占位符），不用 `.outPath`，否则产物自引用。
- 想留覆盖口就照 `modules/wrappers/git.nix`：`configFile` 用 `wlib.types.file { path = lib.mkOptionDefault config.constructFiles.<file>.path; }`。

完成标准：`nix build .#foo` 出包，`$out` 里有 `bin/foo` 和内容正确的生成配置。（wrapper 默认都导出成 `packages.<system>.<name>`；`flake.nix` 的 `wrappers.packages` 里标了 `true` 的会被排除。）

### 2. 先 git add，再 build

flake 源只含 git 跟踪的文件。新目录没 `git add` 时，`nix build .#foo` 报 `flake 'git+file://…' does not provide attribute 'packages.<system>.foo'`；而 `builtins.getFlake (toString ./.)`（`--impure` + 路径，直接拷贝目录）能过——两边结果不一致就先查这个。

```bash
git add modules/wrappers/foo
nix build .#foo
```

完成标准：`nix build .#foo` 成功。

### 3. 确认程序读到的是新配置

跑包装后的二进制，而不是 PATH 里的原版——`env` 只挂在 wrapper 上：

```bash
out="$(nix build .#foo --print-out-paths)"
"$out/bin/foo" --version
```

完成标准：程序用的是 `$out` 里那份配置（用程序自己的 dry-run/verbose 选项，或核对 `$out` 里的配置文件内容）。
