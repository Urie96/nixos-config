{ self, ... }:
{
  flake.homeModules.tinycast =
    {
      pkgs,
      ...
    }:
    let
      system = pkgs.stdenv.hostPlatform.system;
      nur = self.inputs.nur-packages.packages.${system} // self.packages.${system};

      opt = name: {
        inherit name;
        isOptional = true;
      };

      convert_json_to = format: name: {
        name = name;
        runtimeInputs = with pkgs; [
          bat
          coreutils
          nix
          nixfmt
          yq-go
          nur.fmt-file
        ];
        showsOutput = true;
        text = ''
          tmp="$(mktemp)"
           ${
             if format == "json" then
               "pbpaste"
             else if format == "yaml" then
               "pbpaste | yq -o=json ."
             else if format == "toml" then
               "pbpaste | yq -p toml -o=json ."
             else
               throw "format not supported"
           } >"$tmp"

          nix_string="$(nix-instantiate --eval --expr "builtins.fromJSON (builtins.readFile $tmp)" | fmt-file -l nix)"
          rm "$tmp"

          echo "$nix_string" | pbcopy
          echo "$nix_string" | bat --color=always --paging=never --style=plain -l nix
        '';
      };
    in
    {
      programs.tinycast.commands = [
        (convert_json_to "json" "Convert JSON To Nix")
        (convert_json_to "yaml" "Convert YAML To Nix")
        (convert_json_to "toml" "Convert TOML To Nix")
        {
          name = "Date To Unix Timestamp";
          runtimeInputs = with pkgs; [ coreutils ];
          arguments = [ (opt "Date") ];
          text = ''
            DATE="$1"
            if [ -z "$DATE" ]; then
              date +%s
            else
              date -d "$DATE" +%s
            fi | tr -d '\n' | tee >(pbcopy)
          '';
        }
        {
          name = "Date Time";
          runtimeInputs = with pkgs; [
            coreutils
            gnused
          ];
          showsOutput = true;
          text = ''
            DATE="$(date "+%-m月%-d日 周%u %H:%M" | sed -e "s/周1/周一/" -e "s/周2/周二/" -e "s/周3/周三/" -e "s/周4/周四/" -e "s/周5/周五/" -e "s/周6/周六/" -e "s/周7/周日/")"
            echo -e "\033[1;33m''${DATE}\033[0m"
          '';
        }
        {
          name = "Generate QR Code";
          runtimeInputs = with pkgs; [
            coreutils
            qrencode
          ];
          text = ''
            temp="$(mktemp -t XXXXX.png)"
            pbpaste | qrencode -o "$temp"
            open "$temp"

            open -a Preview "$temp"
            /usr/bin/osascript -e 'tell application "Preview"' -e "activate" -e 'tell application "System Events"' -e 'keystroke "9" using { command down}' -e "end tell" -e "end tell"
          '';
        }
        {
          name = "OCR";
          runtimeInputs = with pkgs; [
            coreutils
            pngpaste
            nur.mac-ocr
          ];
          showsOutput = true;
          text = ''
            tmp="$TMPDIR"/pngpaste.png
            pngpaste "$tmp"
            mac-ocr "$tmp"
            rm "$tmp"
          '';
        }
        {
          name = "Translate";
          runtimeInputs = [ nur.translate ];
          arguments = [ (opt "Text") ];
          showsOutput = true;
          text = ''
            translate "$1"
          '';
        }
        {
          name = "Unix Timestamp To Date";
          runtimeInputs = with pkgs; [ coreutils ];
          showsOutput = true;
          text = ''
            unixTime=$(pbpaste)
            length=''${#unixTime}

            if [[ $length == "13" ]]; then
              unixTime=$((unixTime / 1000))
            elif [[ $length != "10" ]]; then
              echo "Unix Time is not found"
              exit 1
            fi
            readable="$(date -d "@$unixTime" "+%F %T")"

            current_time=$(date +%s)
            time_since=$((unixTime - current_time))
            if [ $time_since -lt 0 ]; then
              suffix="前"
              time_since=$((0 - time_since))
            else
              suffix="后"
            fi

            secs=$time_since
            mins=$((secs / 60))
            hours=$((mins / 60))
            days=$((hours / 24))
            months=$((days / 30))
            years=$((days / 365))

            since=""
            if [ $years -gt 0 ]; then
              since="''${years} 年"
            elif [ $months -gt 0 ]; then
              since="''${months} 月"
            elif [ $days -gt 0 ]; then
              since="''${days} 天"
            elif [ $hours -gt 0 ]; then
              since="''${hours} 小时"
            elif [ $mins -gt 0 ]; then
              since="''${mins} 分钟"
            else
              since="''${secs} 秒"
            fi

            echo "$readable ($since$suffix)"
          '';
        }
      ];
    };
}
