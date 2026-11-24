{
  description = "Ladybird browser alpha releases, auto-updated by a GitHub bot";

  nixConfig = {
    extra-substituters = [ "https://sayidabyan.cachix.org" ];
    extra-trusted-public-keys = [
      "sayidabyan.cachix.org-1:AyabZhWClebxTMNzYHJNPX2gDpqxPErYrwCe+tGINC0="
    ];
  };

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      overlays.default = final: _prev: {
        ladybird = final.callPackage ./pkgs/ladybird/package.nix { };
      };

      packages = forAllSystems (pkgs: rec {
        ladybird = pkgs.callPackage ./pkgs/ladybird/package.nix { };
        default = ladybird;
      });

      apps = forAllSystems (pkgs: {
        default = {
          type = "app";
          program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.ladybird}/bin/Ladybird";
          meta.description = "Run Ladybird";
        };
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            jq
            curl
            git
            nixfmt
          ];
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
