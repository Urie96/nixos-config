{
  flake.droidModules.update-dns =
    { pkgs, lib, ... }:
    let
      update-dns = pkgs.python3.pkgs.buildPythonApplication {
        pname = "update-dns";
        version = "0.1.0";
        src = ./update-dns;
        pyproject = false;
        dontWrapPythonPrograms = true;
        installPhase = ''
          runHook preInstall
          mkdir -p $out/bin
          install -m 755 update-dns $out/bin/update-dns
          runHook postInstall
        '';
      };
    in
    {
      environment.loginHook = ''
        ${update-dns}/bin/update-dns
      '';

      environment.packages = [ update-dns ];

      # resolv.conf is generated on demand by `update-dns` (dumpsys connectivity).
      # Disabling the static entry keeps `switch` from overwriting it; the old
      # symlink is cleaned up by activation, leaving room for the runtime file.
      environment.etc."resolv.conf" = {
        enable = lib.mkForce false;
      };
    };
}
