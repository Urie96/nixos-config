{
  flake.homeModules.tinycast =
    {
      pkgs,
      ...
    }:
    let
      req = name: {
        inherit name;
        isOptional = false;
      };

      link = name: url: {
        inherit name;
        text = "open '${url}'";
      };
    in
    {
      programs.tinycast.commands = [
        (link "BAM" "https://cloud.bytedance.net/bam/rd")
        (link "Overpass" "https://cloud.bytedance.net/overpass/idl")
        (link "Feishu Doc" "https://bytedance.feishu.cn/wiki/wikcnWaStFEanTzpLyhWXsxm98d")
        (link "TCC" "https://cloud.bytedance.net/tcc/namespace")
        {
          name = "Github Search";
          arguments = [ { name = "Repository"; } ];
          text = ''open "https://github.com/search?q=$1&type=repositories"'';
        }
        {
          name = "Google Search";
          arguments = [ (req "Keyword") ];
          text = ''open "https://www.google.com/search?q=$1" '';
        }
        {
          name = "Rust Doc Search";
          arguments = [ (req "Keyword") ];
          text = ''
            open "https://docs.rs/releases/search?query=$1"
          '';
        }
        {
          name = "Search Nix Function";
          arguments = [ (req "Keyword") ];
          text = ''
            open "https://noogle.dev/q?term=$1"
          '';
        }
        {
          name = "ChatGPT";
          runtimeInputs = with pkgs; [ jq ];
          arguments = [ (req "Prompt") ];
          text = ''
            open "https://chatgpt.com/?q=$(echo $1 | jq -sRr @uri)"
          '';
        }
      ];
    };
}
