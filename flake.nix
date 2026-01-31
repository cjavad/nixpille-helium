{
  description = "Helium browser — a private, fast, and honest web browser";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          helium = pkgs.callPackage ./package.nix { };
          default = self.packages.${system}.helium;
        }
      );

      homeModules.default = import ./hm-module.nix self;

      overlays.default = final: _: {
        helium = self.packages.${final.stdenv.hostPlatform.system}.default;
      };
    };
}
