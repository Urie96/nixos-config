{ self, ... }:
{
  flake.wrappers.yazi =
    {
      config,
      wlib,
      lib,
      pkgs,
      ...
    }:
    let
      # paperless opener 的脚本。
      sendToPaperless = pkgs.writeShellScript "send-to-paperless" (
        builtins.readFile ./scripts/send-to-paperless
      );
    in
    {
      imports = [
        wlib.wrapperModules.yazi
      ];

      plugins =
        let
          officialPlugins = pkgs.fetchFromGitHub {
            owner = "yazi-rs";
            repo = "plugins";
            rev = "c591a36e7263e95497715d525e9c46c2f0a880ac";
            hash = "sha256-mWT0yF2iG9+gYEuNiffpM93POlBqY+QKdFh5jSAxYls=";
          };
          mkOfficialPlugin = name: "${officialPlugins}/${name}.yazi";
          nur = self.inputs.nur-packages.packages.${pkgs.stdenv.hostPlatform.system};
        in
        {
          zoom = mkOfficialPlugin "zoom";
          toggle-pane = mkOfficialPlugin "toggle-pane";
          piper = mkOfficialPlugin "piper";
          mount = mkOfficialPlugin "mount";
          mime-ext = mkOfficialPlugin "mime-ext";
          git = mkOfficialPlugin "git";
          full-border = mkOfficialPlugin "full-border";
          chmod = mkOfficialPlugin "chmod";
          preview-bin = "${nur.preview}/preview-bin.yazi";
        };

      # nix-wrapper-modules 的 yazi 模块只通过 constructFiles 生成 *.toml，没有提供 init.lua 的 option。
      # 这里复用底层通用的 constructFiles 机制，把 init.lua 放进与 yazi.toml 相同的目录
      # （即 $out/yazi-config/，也就是 wrapper 设置的 YAZI_CONFIG_HOME）。
      # 参考 yazi 模块自身的写法，用 mkOverride 0 与 toml 文件保持在同一输出。
      constructFiles.initLua = {
        content = builtins.readFile ./config/init.lua;
        relPath = lib.mkOverride 0 "${config.binName}-config/init.lua";
        output = lib.mkOverride 0 config.generatedConfig.output;
      };

      settings.yazi = {
        mgr = {
          ratio = [
            1
            3
            4
          ];
          sort_by = "mtime";
          sort_reverse = true;
        };

        preview = {
          max_height = 1000;
          max_width = 1000;
          wrap = "no";
          image_delay = 100;
        };

        open = {
          prepend_rules = [
            {
              url = "*.apk";
              use = [ "operate_apk" ];
            }
            {
              mime = "{video,audio}/*";
              use = [
                "xopen"
                "play"
                "reveal"
              ];
            }
            {
              mime = "*/pdf";
              use = [
                "pdf_to_png"
                "reveal"
                "paperless"
              ];
            }
            # 默认的 image/* 规则（open + reveal）加上 paperless，
            # 这样图片也能从 `r`（open --interactive）里选到。
            {
              mime = "image/*";
              use = [
                "open"
                "reveal"
                "paperless"
              ];
            }
            {
              url = "*kicad_*/";
              use = [
                "xopen"
                "reveal"
              ];
            }
          ];
        };

        opener = {
          xopen = [
            {
              run = "xopen %s1";
              desc = "xopen";
            }
          ];
          operate_apk = [
            {
              run = "${pkgs.writeShellScript "adb_install" ''
                set +e
                ANDROID_SERIAL="$(command adb devices -l | grep -E '\sdevice\s' | fzf --bind one:accept --exit-0 | awk '{print $1}')"
                export ANDROID_SERIAL

                while [[ $# -gt 0 ]]; do
                    adb install -r "$1"
                    shift
                done
              ''} %s1";
              desc = "Install apk via ADB";
              block = true;
            }
            {
              run = "${pkgs.writeShellScript "sign_apk" ''
                INPUT="$1"
                KEYSTORE=~/.android/personal.keystore
                PASSWORD="$(rbw get apksigner-personal-password)"
                ALIAS=personal

                DIR="$(dirname "$INPUT")"
                BASE="$(basename "$INPUT" .apk)"
                OUTPUT="$DIR/''${BASE}_signed.apk"

                apksigner sign \
                  --ks "$KEYSTORE" \
                  --ks-pass "pass:$PASSWORD" \
                  --ks-key-alias "$ALIAS" \
                  --key-pass "pass:$PASSWORD" \
                  --out "$OUTPUT" \
                  "$INPUT"

                apksigner verify --verbose --print-certs "$OUTPUT"
              ''} %s1";
              desc = "Sign .apk";
              block = true;
            }
          ];
          # 发送到 paperless-ngx。token 直接用环境变量 PAPERLESS_TOKEN，
          # 该变量由 fish wrapper 的 load-secrets.fish 导出，yazi 从 fish 启动即继承。
          # 要让它对其它类型也在 `r` 里可见，把 "paperless" 加进对应规则的 `use`。
          paperless = [
            {
              run = "${sendToPaperless} %s";
              desc = "Send to Paperless";
              # 一次调用拿到全部选中项，脚本里逐个上传，输出不会交错。
              spread = true;
              block = true;
            }
          ];
          pdf_to_png = [
            {
              run = "${pkgs.writeShellScript "pdf_to_png" ''
                while [[ $# -gt 0 ]]; do
                    pdf_file="$1"
                    dir="''${pdf_file%.pdf}"
                    dir="''${dir%.PDF}" # Handle uppercase .PDF extension
                    mkdir -p -- "$dir"
                    # 输出文件名格式为: dir/page-1.png, dir/page-2.png, ...
                    pdftoppm -png -- "$pdf_file" "$dir/page"
                    shift
                done
              ''} %s";
              desc = "Extract png from PDF";
              block = true;
            }
          ];
        };

        plugin = {
          preloaders = [ ];
          prepend_previewers = [
            # 图片统一交给 preview-bin（包括 pdf 页、视频缩略图、raf/svg 转换出来的图）：
            # 它在 SSH 会话里用 chafa 输出 Unicode 块字符，不再通过连接传 kitty/sixel
            # 图片数据；非 SSH 会话仍是 ya.image_show。
            # 下面两条是 yazi 内置解码不支持的格式，仍走内置插件。
            {
              run = "magick";
              mime = "image/{avif,hei?,jxl}";
            }
            {
              run = "svg";
              mime = "image/svg+xml";
            }
            {
              run = "preview-bin";
              mime = "image/*";
            }
          ];
          append_previewers = [
            {
              run = "preview-bin";
              url = "*";
            }
          ];
          prepend_fetchers = [
            {
              group = "mime";
              prio = "high";
              run = "mime-ext.local";
              url = "local://*";
            }
            {
              group = "mime";
              prio = "high";
              run = "mime-ext.remote";
              url = "remote://*";
            }
            {
              group = "git";
              url = "*";
              run = "git";
            }
            {
              group = "git";
              url = "*/";
              run = "git";
            }
          ];
        };
      };

    };

  # 安装入口：modules/base.nix 里 `imports = with self.<class>; [ yazi ]` 引用。
  # 通用的 install 模块只为声明 `wrappers.yazi.*` 选项，真正落地靠 enable 打开。
  flake.nixosModules.yazi = {
    wrappers.yazi.enable = true;
  };
  flake.darwinModules.yazi = {
    wrappers.yazi.enable = true;
  };
  flake.sysModules.yazi = {
    wrappers.yazi.enable = true;
  };
  flake.droidModules.yazi = {
    wrappers.yazi.enable = true;
  };
}
