{
  description = "Flake to accompany https://n8henrie.com/2023/09/compiling-rust-for-the-esp32-with-nix/";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-23.05";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    rust-overlay,
  }: let
    inherit (nixpkgs) lib;
    systems = ["aarch64-darwin" "x86_64-linux" "aarch64-linux"];
    systemClosure = attrs:
      builtins.foldl' (acc: system:
        lib.recursiveUpdate acc (attrs system)) {}
      systems;
  in
    systemClosure (
      system: let
        inherit ((builtins.fromTOML (builtins.readFile ./Cargo.toml)).package) name;
        pkgs = import nixpkgs {
          inherit system;
          overlays = [(import rust-overlay)];
        };
        toolchain = (
          pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml
        );
        rustPlatform = let
          pkgsCross = import nixpkgs {
            inherit system;
            crossSystem = {
              inherit system;
              rustc.config = "riscv32imc-unknown-none-elf";
            };
          };
        in
          pkgsCross.makeRustPlatform
          {
            rustc = toolchain;
            cargo = toolchain;
          };
      in {
        packages.${system}.default = pkgs.callPackage ./. {
          inherit name rustPlatform;
        };

        devShells.${system}.default = pkgs.mkShell {
          name = "${name}-dev";
          shellHook = ''
            export CARGO_HOME="''${XDG_CACHE_HOME}/cargo";
            export CARGO_TARGET_DIR="''${XDG_CACHE_HOME}/cargo-build-nix/${name}"
          '';
          SSID="foo";
          PASSWORD="bar";
          buildInputs = [
            pkgs.cargo-espflash
            toolchain
          ];
        };

        apps.${system}.default = let
          flash = pkgs.writeShellApplication {
            name = "flash-${name}";
            runtimeInputs = [pkgs.cargo-espflash];
            text = ''
              espflash --monitor ${self.packages.${system}.default}/bin/${name}
            '';
          };
        in {
          type = "app";
          program = "${flash}/bin/flash-${name}";
        };
      }
    );
}
