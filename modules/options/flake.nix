{ lib, moduleLocation, ... }:
let

  # 声明一个可按属性名合并的 `flake.<output>` 模块集合(如 flake.nixosModules)。
  #
  # flake-parts 只为 flake.nixosModules / flake.nixosConfigurations / flake.overlays
  # 等少数输出声明了可合并的 option(见 flake-parts/modules/nixosModules.nix),
  # 其余输出会落到 "flake" 的 freeformType (lazyAttrsOf (unique raw)) 上,只能被定义一次;
  # 当 modules/ 下有多个文件都定义 `flake.<output>.<name>` 时,合并就会报
  # "The option `flake.<output>' is defined multiple times"。
  # 这里显式声明它,让它像 flake.nixosModules 一样可以按属性名合并。
  #
  # `class` 会和 flake-parts 一样给模块打上 _class / _file:
  # 这样把它误导入 class 不匹配的 eval 时会立刻报错,
  # 报错信息里也能指出是 flake.nix#<output>.<name> 这个模块。
  # 传 null 表示该 module system 的 evalModules 没有设置 class(如 system-manager),
  # 此时只打 _file(_class 不参与校验)。
  mkModuleOutput =
    {
      output,
      class,
      description,
    }:
    lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.deferredModule;
      default = { };
      apply = lib.mapAttrs (
        k: v:
        {
          _file = "${toString moduleLocation}#${output}.${k}";
          imports = [ v ];
        }
        // lib.optionalAttrs (class != null) { _class = class; }
      );
      inherit description;
    };
in
{

  # options.flake.darwinModules = mkModuleOutput {
  #   output = "darwinModules";
  #   class = "darwin";
  #   description = "nix-darwin modules, keyed by module name.";
  # };

  # nix-on-droid 的模块 class 见 nix-on-droid/modules/default.nix(class = "nixOnDroid")。
  options.flake.droidModules = mkModuleOutput {
    output = "droidModules";
    class = "nixOnDroid";
    description = "nix-on-droid modules, keyed by module name.";
  };

  # system-manager 的 makeSystemConfig 用 lib.evalModules 但没有设置 class,
  # 所以这里不打 _class,只保留 _file(见 system-manager/nix/lib.nix)。
  options.flake.sysModules = mkModuleOutput {
    output = "sysModules";
    class = null;
    description = "system-manager modules, keyed by module name.";
  };

}
