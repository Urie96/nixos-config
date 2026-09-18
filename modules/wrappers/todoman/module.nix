{
  flake.wrappers.todoman =
    {
      config,
      lib,
      wlib,
      pkgs,
      ...
    }:
    let
      # settings 允许的值：bool / int / float / str / 嵌套 list / 嵌套 dict，
      # 以及 null（表示不写这一行）。
      pythonValue = lib.types.nullOr (
        lib.types.oneOf [
          lib.types.bool
          lib.types.int
          lib.types.float
          lib.types.str
          (lib.types.listOf pythonValue)
          (lib.types.attrsOf pythonValue)
        ]
      );

      # todoman 的 config.py 是一段 Python 源码，配置项就是模块里的顶层变量，
      # 所以这里把 Nix 值渲染成 Python 字面量。注意 builtins.toJSON 的
      # true/false/null 不是合法 Python，bool 和 null 要单独处理。
      toPython =
        value:
        if value == null then
          "None"
        else if builtins.isBool value then
          (if value then "True" else "False")
        else if builtins.isInt value then
          toString value
        else if builtins.isFloat value then
          # toString 会给出 1.500000，toJSON 给出 1.5
          builtins.toJSON value
        else if builtins.isString value then
          builtins.toJSON value
        else if builtins.isList value then
          "[ ${lib.concatMapStringsSep ", " toPython value} ]"
        else if builtins.isAttrs value then
          "{ ${
            lib.concatMapStringsSep ", " (
              name: "${toPython name}: ${toPython value.${name}}"
            ) (builtins.attrNames value)
          } }"
        else
          throw "todoman wrapper: 无法把 ${builtins.typeOf value} 渲染成 Python 字面量";

      renderEntry =
        name: value:
        if builtins.match "[A-Za-z_][A-Za-z0-9_]*" name == null then
          throw "todoman wrapper: `settings.${name}` 不是合法的 Python 变量名"
        else
          "${name} = ${toPython value}\n";

      # null 表示「不生成这一行」，交给 todoman 用它自己的默认值。
      rendered = lib.concatStrings (
        lib.mapAttrsToList renderEntry (lib.filterAttrs (_: value: value != null) config.settings)
      );

      generated = ''
        # 由 nix-wrapper-modules 生成，请勿手改（改 modules/wrappers/todoman）。
        ${rendered}
      '' + config.extraConfig;
    in
    {
      imports = [ wlib.modules.default ];

      options = {
        settings = lib.mkOption {
          type = lib.types.attrsOf pythonValue;
          default = { };
          example = lib.literalExpression ''
            {
              path = "~/.calendars/*";
              default_list = "personal";
              default_priority = 5;
              humanize = true;
            }
          '';
          description = ''
            todoman `config.py` 里的顶层变量，键名与 todoman 的配置项一致
            （见 todoman 仓库的 `config.py.sample` 和
            <https://todoman.readthedocs.io/en/stable/configure.html>）。
            这里不枚举键名，上游新增配置项时不用改 wrapper。
            值为 `null` 的项不写入文件，使用 todoman 自带默认值。
          '';
        };

        extraConfig = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = ''
            追加到生成文件末尾的原始 Python 代码，用于 `settings` 表达不了的写法
            （例如 import、表达式；todoman 会忽略不认识的顶层变量）。
          '';
        };

        configFile = lib.mkOption {
          type = lib.types.nullOr wlib.types.stringable;
          default = null;
          description = ''
            直接指定一份现成的 `config.py`，设置后通过 `TODOMAN_CONFIG` 用它，
            完全覆盖 `settings` / `extraConfig`（但生成的文件仍留在 wrapper 输出里）。
          '';
        };

        configText = lib.mkOption {
          type = lib.types.lines;
          readOnly = true;
          description = "最终写进 wrapper 输出里那份 `config.py` 的文本。";
        };
      };

      config = {
        package = lib.mkDefault pkgs.todoman;

        configText = generated;

        # 和 git/vdirsyncer 一样，把配置文件和 wrapper 放进同一个输出，
        # 再用 TODOMAN_CONFIG 指过去，避免产物自引用。
        constructFiles.todomanConfig = {
          relPath = "${config.binName}config.py";
          content = config.configText;
        };

        # pkgs.todoman 的可执行文件叫 `todo`（meta.mainProgram），
        # 所以 wrapper 输出的是 $out/bin/todo。
        env.TODOMAN_CONFIG =
          if config.configFile != null then config.configFile else config.constructFiles.todomanConfig.path;

        meta.description = "todoman（`todo`），config.py 由 `settings` 生成并通过 TODOMAN_CONFIG 指向。";
      };
    };
}
