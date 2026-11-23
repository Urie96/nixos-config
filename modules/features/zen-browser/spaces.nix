# Zen 的 Space 与固定标签页（pins），声明式管理。
#
# 数据来源：当前 profile 的 zen-sessions.jsonlz4（mozLz4 压缩）。重新导出用：
#
#   python3 scripts/mozlz4.py \
#     ~/Library/Application\ Support/zen/Profiles/default/zen-sessions.jsonlz4 | jq '.spaces'
#
# ⚠ 改这个文件后要先关掉 Zen 再 switch：activation 会解压 zen-sessions.jsonlz4、
#   跑 jq 合并、再压回去，浏览器开着时写入会被它自己的 session 保存覆盖。
# ⚠ 改 space 的 id 等于新建一个 space（旧 space 里的 tab 不跟过去）；在
#   spacesForce = true 的情况下旧 space 还会被删掉。
#
# pins 写成列表，id 和 position 都不用手写（见下面 mkPins）：
#   - position = (下标 + 1) * 100，列表顺序就是侧栏顺序；
#   - id = sha256(spaceId|url) 拼出来的 UUID 形状。这是求值器内建的 hashString，
#     纯字符串运算，不建 derivation、不写 store，所以不是 IFD（对比之下，用
#     yq 把 YAML 转 JSON 那种才是）。同一个 space 里同一个 url 永远得到同一个 id。
#   代价：改 url 就是换 id，旧 pin 会变成「未声明」（pinsForce 关着时不会被删，
#   只会多出一条，手动删一次）。需要长期锁定就在条目里显式写 id。
{
  flake.homeModules.zen-browser =
    {
      lib,
      ...
    }:
    let
      # sha256 前 32 个 hex → 8-4-4-4-12。Zen 只把它当不透明字符串
      # （zenSyncId / 文件夹 id 都只是 "{<id>}"），不校验 UUID 版本位。
      uuidFrom =
        seed:
        let
          h = builtins.hashString "sha256" seed;
          at = n: len: builtins.substring n len h;
        in
        "${at 0 8}-${at 8 4}-${at 12 4}-${at 16 4}-${at 20 12}";

      # 条目里允许出现的键。没列出来的（拼错的）会直接报错，而不是在
      # 模块求值时报一句指向 hash 属性名的莫名其妙的话。
      allowedKeys = [
        "title"
        "url"
        "container"
        "isEssential"
        "editedTitle"
        "isFolderCollapsed"
        "folderIcon"
        "id"
        "pins"
      ];

      # 条目列表 → spaces.*.pins。条目形如：
      #   { title = "GitHub"; url = "https://github.com/"; }
      #   { title = "视频"; isFolderCollapsed = true; pins = [ … ]; }   # 文件夹
      # 除了 title 以外都可以省略；pins 只在文件夹上用，isGroup 自动补。
      #
      # 属性名取 title：同 space 内必须唯一，否则 listToAttrs 会静默覆盖；
      # id 则必须全局唯一（各 space 的 pin 最后会合并进同一个扁平 pins，
      # zenSyncId / 文件夹 id 都是它），所以 scope 里带的是 space 的 uuid 而不是
      # space 名 —— 重命名 space 不会让所有 pin 换 id。
      mkPins =
        scope: entries:
        let
          toEntry =
            idx: e:
            let
              id = e.id or (uuidFrom "${scope}|${e.url or e.title}");
            in
            {
              name = e.title;
              value =
                removeAttrs e [
                  "id"
                  "pins"
                ]
                // {
                  inherit id;
                  position = (idx + 1) * 100;
                }
                // lib.optionalAttrs (e ? pins) {
                  isGroup = true;
                  pins = mkPins "${scope}|${id}" e.pins;
                };
            };

          pins = lib.listToAttrs (lib.imap0 toEntry entries);
          ids = map (p: p.id) (lib.attrValues pins);

          scopeName = lib.replaceStrings [ "/" ] [ "." ] scope;
        in
        assert lib.assertMsg (lib.all (
          e: lib.all (k: lib.elem k allowedKeys) (lib.attrNames e)
        ) entries) "zen-browser: ${scopeName} 的 pin 条目里有不认识的键，合法键见 allowedKeys";
        assert lib.assertMsg (
          lib.length entries == lib.length (lib.attrValues pins)
        ) "zen-browser: ${scopeName} 里 pin 的 title 有重复，同名的只会保留最后一条";
        assert lib.assertMsg (
          lib.length ids == lib.length (lib.unique ids)
        ) "zen-browser: ${scopeName} 里两个 pin 算出了同一个 id（同一个 url 出现了两次？）";
        pins;

      # 必须和 Zen 里现有的 space 一致：换成新 uuid 等于新建一个 space。
      studyId = "baec42c2-d906-4852-aa1c-f8f89cd01cf4";
      workId = "93b2250c-a4cb-4b70-8dbe-379301d9f652";
    in
    {
      programs.zen-browser.profiles.default = {
        spacesForce = true;

        spaces = {
          study = {
            id = studyId;
            position = 1000;
            icon = "📖";

            pins = mkPins studyId [
              {
                title = "视频";
                isFolderCollapsed = true;
                pins = [
                  {
                    title = "YouTube";
                    url = "https://www.youtube.com/";
                  }
                  {
                    title = "哔哩哔哩";
                    url = "https://www.bilibili.com/";
                  }
                ];
              }
              {
                title = "Reddit";
                url = "https://reddit.com/";
              }
              {
                title = "GitHub";
                url = "https://github.com/";
              }
              {
                title = "DeepSeek";
                url = "https://chat.deepseek.com/";
              }
              {
                title = "Gitea";
                url = "https://git.lubui.com:8443/urie";
              }
            ];

            # 渐变主题。注意 theme 是整对象替换（writer 里 $existing * $declared），
            # 这里漏写 colors 会把 Zen 里现有的渐变清成空列表。
            theme = {
              colors = [
                {
                  red = 107;
                  green = 125;
                  blue = 174;
                  algorithm = "analogous";
                  type = "explicit-lightness";
                  lightness = 55;
                  primary = true;
                  position = {
                    x = 81;
                    y = 84;
                  };
                }
                {
                  red = 144;
                  green = 107;
                  blue = 174;
                  algorithm = "analogous";
                  type = "explicit-lightness";
                  lightness = 55;
                  primary = false;
                  position = {
                    x = 189;
                    y = 43;
                  };
                }
                {
                  red = 107;
                  green = 174;
                  blue = 168;
                  algorithm = "analogous";
                  type = "explicit-lightness";
                  lightness = 55;
                  primary = false;
                  position = {
                    x = 43;
                    y = 193;
                  };
                }
              ];
              opacity = 0.5;
              texture = 0.0;
            };
          };

          work = {
            id = workId;
            position = 2000;
            icon = "💼";

            routes = {
              "byted".reference = "byted.org";
              "bytedance".reference = "bytedance.net";
            };

            theme = {
              colors = [
                {
                  red = 217;
                  green = 199;
                  blue = 89;
                  algorithm = "analogous";
                  type = "explicit-lightness";
                  lightness = 60;
                  primary = true;
                  position = {
                    x = 225;
                    y = 237;
                  };
                }
                {
                  red = 126;
                  green = 217;
                  blue = 89;
                  algorithm = "analogous";
                  type = "explicit-lightness";
                  lightness = 60;
                  primary = false;
                  position = {
                    x = 164;
                    y = 252;
                  };
                }
                {
                  red = 217;
                  green = 91;
                  blue = 89;
                  algorithm = "analogous";
                  type = "explicit-lightness";
                  lightness = 60;
                  primary = false;
                  position = {
                    x = 253;
                    y = 181;
                  };
                }
              ];
              opacity = 0.5;
              texture = 0.0;
            };
          };
        };
      };
    };
}
