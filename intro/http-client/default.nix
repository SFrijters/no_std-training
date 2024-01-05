{
  lib,
  rustPlatform,
  name,
}: (rustPlatform.buildRustPackage
  {
    inherit name;
    src = lib.cleanSource ./.;
    cargoLock = {
      lockFile = ./Cargo.lock;
      outputHashes = {
        "esp-wifi-0.1.0" = "sha256-IUkX3inbeeRZk9q/mdg56h+qft+0/TVpOM4rCKNOwz8=";
      };
    };
    SSID = "foo";
    PASSWORD = "bar";
    doCheck = false;
  })
