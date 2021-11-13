{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
  let
    ffnixModule = import ./.;
  in {
    overlay = final: prev: {
      batman-adv-legacy = kernelPackages: kernelPackages.callPackage ./batman-adv-legacy.nix {};
      batctl-legacy = final.callPackage ./batctl-legacy.nix {};
    };
    overlays = [ self.overlay ];
    nixosModules.ffnix = ffnixModule;
    nixosModule = ffnixModule;
  };
}
