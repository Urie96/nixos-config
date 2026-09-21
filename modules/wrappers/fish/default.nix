{
  flake.wrappers.fish =
    {
      wlib,
      lib,
      pkgs,
      ...
    }:
    let
      # ./functions 下的每个 *.fish 文件自动注册成一个 fish function，
      # 文件名（去掉 .fish 后缀）就是函数名。
      functionFiles = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".fish" name) (
        builtins.readDir ./functions
      );

      # ./conf.d 下的每个 *.fish 文件按文件名字典序（与 fish 自身加载 conf.d 的顺序一致）
      # 拼接进 interactiveShellInit。
      confDFiles =
        let
          entries = builtins.readDir ./conf.d;
          names = lib.sort (a: b: a < b) (
            lib.filter (name: entries.${name} == "regular" && lib.hasSuffix ".fish" name) (
              builtins.attrNames entries
            )
          );
        in
        map (name: builtins.readFile ./conf.d/${name}) names;
    in
    {
      flags."--no-config" = false;

      shellInit = ''
        set -gx FZF_DEFAULT_OPTS_FILE ${./fzfrc}

        set -gx HF_ENDPOINT 'https://hf-mirror.com'
        set -gx LANG 'zh_CN.UTF-8'
        set -gx MANPAGER 'nvim +Man!'
        set -gx PNPM_HOME ~/.local/share/pnpm
        set -gx XDG_CACHE_HOME ~/.cache
        set -gx XDG_CONFIG_HOME ~/.config
        set -gx XDG_DATA_HOME ~/.local/share
        set -gx XDG_STATE_HOME ~/.local/state
        set -gx EDITOR nvim

        fish_add_path -g -m ~/bin ~/.local/bin ~/.local/state/nix/profile/bin /run/wrappers/bin /run/current-system/sw/bin /nix/var/nix/profiles/default/bin "$PNPM_HOME/bin" "$HOME/.cargo/bin" /opt/homebrew/bin /opt/homebrew/sbin

        set -l wrapped_fish_runtime_dir $XDG_RUNTIME_DIR
        if test -z "$wrapped_fish_runtime_dir"
            set wrapped_fish_runtime_dir /tmp
        end
        set -l wrapped_fish_load_secrets $wrapped_fish_runtime_dir/wrapped-fish/load-secrets.fish

        if test -f $wrapped_fish_load_secrets
            source $wrapped_fish_load_secrets
        else
            refresh-secrets
        end
      '';

      interactiveShellInit = lib.concatStringsSep "\n" (
        confDFiles
        ++ [
          ''
            if command -q zoxide
                zoxide init fish | source
            end

            if command -q devenv
                source ${./devenv.fish}
            end

            fish_config theme choose catppuccin-mocha --color-theme=dark
          ''
        ]
      );

      shellFunctions =
        (lib.mapAttrs' (
          name: _:
          lib.nameValuePair (lib.removeSuffix ".fish" name) {
            body = builtins.readFile ./functions/${name};
          }
        ) functionFiles)
        // {
          refresh-secrets = {
            modifiers.description = "重新解密 sops secrets 并生成 load-secrets.fish 缓存";
            body = ''
              set -l runtime_dir /tmp
              if test -n "$XDG_RUNTIME_DIR"
                  set runtime_dir $XDG_RUNTIME_DIR
              end
              set -l out_dir $runtime_dir/wrapped-fish
              set -l out_file $out_dir/load-secrets.fish

              if not command mkdir -p $out_dir
                  echo "refresh-secrets: 无法创建目录 $out_dir" >&2
                  return 1
              end

              # 先写临时文件，成功后再原子替换，避免解密失败留下不完整的缓存。
              set -l tmp_file (command mktemp $out_dir/load-secrets.XXXXXX)
              if test -z "$tmp_file"
                  echo "refresh-secrets: 无法在 $out_dir 创建临时文件" >&2
                  return 1
              end

              set -l secrets_json (${lib.getExe pkgs.sops} decrypt --output-type json ${./secrets.yaml})
              or begin
                  echo "refresh-secrets: sops 解密失败，保留旧的 $out_file" >&2
                  command rm -f $tmp_file
                  return 1
              end

              if not printf '%s\n' $secrets_json | ${lib.getExe pkgs.jq} -r 'to_entries[] | "set -gx \(.key) \(.value | @sh)"' > $tmp_file
                  echo "refresh-secrets: 生成 fish 代码失败，保留旧的 $out_file" >&2
                  command rm -f $tmp_file
                  return 1
              end

              command chmod 600 $tmp_file
              command mv -f $tmp_file $out_file
              echo "refresh-secrets: 已更新 $out_file"

              source $out_file
            '';
          };
        };
    };
}
