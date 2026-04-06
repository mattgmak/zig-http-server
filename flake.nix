{
  description = "Zig dev shell";
  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };
    zig-overlay.url = "github:mitchellh/zig-overlay";
    zls = {
      url = "github:zigtools/zls";
      inputs.zig-overlay.follows = "zig-overlay";
    };
  };

  outputs =
    {
      nixpkgs,
      zig-overlay,
      zls,
      ...
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      pkgsFor =
        system: pkgs:
        import pkgs {
          inherit system;
          config.allowUnfree = true;
        };
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system nixpkgs;
        in
        {
          default = pkgs.mkShell {
            packages = [
              zig-overlay.packages.${system}.master-2026-04-05
              zls.packages.${system}.default
              pkgs.zlint
            ];
          };
        }
      );
    };
}
