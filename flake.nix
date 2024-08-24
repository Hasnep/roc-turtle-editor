{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  nixConfig = {
    extra-trusted-public-keys = "roc-lang.cachix.org-1:6lZeqLP9SadjmUbskJAvcdGR2T5ViR57pDVkxJQb8R4=";
    extra-trusted-substituters = "https://roc-lang.cachix.org";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      perSystem =
        {
          inputs',
          pkgs,
          ...
        }:
        {
          devShells.default = pkgs.mkShell {
            name = "roc-turtle-editor";
            packages = [
              # Gleam
              pkgs.gleam
              pkgs.erlang
              pkgs.rebar3
              pkgs.coreutils
              # Other
              pkgs.docker
              pkgs.flyctl
              pkgs.just
              pkgs.nodePackages.prettier
            ];
          };
          formatter = pkgs.nixfmt-rfc-style;
        };
    };
}
