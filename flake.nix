{
  description = "agda2lambox";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        agdasrc = pkgs.fetchFromGitHub {
          owner = "agda";
          repo = "agda";
          rev = "5c29109f8212ef61b0091d62ef9c8bfdfa16cf36";
          hash = "sha256-qiV/tk+/b3xYPJcWVVd7x9jrQjBzl1TXHPNEQbKV2rA=";
        };
        hpkgs =
          with pkgs;
          haskellPackages.override {
            overrides = _: old: {
              Agda =
                let
                  newsrc = haskell.lib.overrideSrc old.Agda {
                    src = agdasrc;
                    version = "2.8.0";
                  };
                  adddeps = haskell.lib.overrideCabal newsrc (drv: {
                    libraryHaskellDepends =
                      drv.libraryHaskellDepends
                      ++ (with old; [
                        enummapset
                        filemanip
                        generic-data
                        nonempty-containers
                        process-extras
                        tasty
                        tasty-hunit
                        tasty-quickcheck
                        tasty-silver
                        temporary
                        unix-compat
                      ]);
                  });
                in
                adddeps;
            };
          };
        agda2lambox = hpkgs.callCabal2nix "agda2lambox" ./. { };
      in
      {
        packages = {
          inherit agda2lambox;
          default = agda2lambox;
        };
        devShells.default = pkgs.haskellPackages.shellFor {
          packages = p: [ agda2lambox ];
          buildInputs = with pkgs.haskellPackages; [
            cabal-install
            cabal2nix
            haskell-language-server
            pkgs.agda
          ];
        };
      }
    );
}
