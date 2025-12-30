{
  description = "NixOS on Radxa Zero 3W with WiFi support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators }:
    let
      system = "aarch64-linux";
    in
    {
      nixosConfigurations.radxa-zero3w = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          {
            system.configurationRevision = self.rev or "dirty";
          }
          ./configuration.nix
        ];
      };

      # Flashable SD card image
      packages.aarch64-linux.default = nixos-generators.nixosGenerate {
        inherit system;
        format = "sd-aarch64";
        modules = [
          ./configuration.nix
          { sdImage.compressImage = false; }
        ];
      };

      # Alias for convenience
      packages.aarch64-linux.sdImage = self.packages.aarch64-linux.default;
    };
}
