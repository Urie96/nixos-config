let
  make-singbox-var =
    {
      remote_ip,
      remote_domain,
      name,
    }:
    { pkgs, ... }:
    {
      clan.core.vars.generators.${name} = {
        share = true;
        files = {
          "key".owner = "sing-box";
          "crt".secret = false;
          "uuid".owner = "sing-box";
          "remote_ip".secret = false;
          "remote_domain".secret = false;
        };
        runtimeInputs = with pkgs; [
          openssl
          python3
        ];
        script = ''
          echo -n ${remote_ip} > $out/remote_ip
          echo -n ${remote_domain} > $out/remote_domain

          python3 -c "import uuid; print(uuid.uuid4())" > $out/uuid

          openssl req -x509 -newkey rsa:2048 -nodes \
            -keyout $out/key \
            -out $out/crt \
            -days 3650 \
            -subj "/CN=${remote_domain}" \
            -addext "subjectAltName=DNS:${remote_domain},IP:${remote_ip}"
        '';
      };
    };

  singbox-kr-var = make-singbox-var {
    remote_domain = "kr.lubui.buzz";
    remote_ip = "43.133.236.247";
    name = "sing-box-kr";
  };
  singbox-kr-config = import ./_make-singbox-oversea.nix "sing-box-kr";

  singbox-hk-var = make-singbox-var {
    remote_domain = "jp.lubui.buzz";
    remote_ip = "47.76.155.157";
    name = "sing-box-hk";
  };
  singbox-hk-config = import ./_make-singbox-oversea.nix "sing-box-hk";
in

{
  flake.nixosModules.singbox-home = {
    imports = [
      singbox-hk-var
      singbox-kr-var
      ./_singbox-home.nix
    ];
  };

  flake.nixosModules.singbox-kr = {
    imports = [
      singbox-kr-var
      singbox-kr-config
    ];
  };
  flake.nixosModules.singbox-hk = {
    imports = [
      singbox-hk-var
      singbox-hk-config
    ];
  };
}
