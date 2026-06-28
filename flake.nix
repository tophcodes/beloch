{
  description = "Beloch — a declarative language for origami";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        ocamlPkgs = pkgs.ocamlPackages;

        beloch = ocamlPkgs.buildDunePackage {
          pname = "beloch";
          version = "0.0.0-dev";
          src = ./.;
          duneVersion = "3";
          nativeBuildInputs = [ ocamlPkgs.menhir ];
          buildInputs = [
            ocamlPkgs.zarith
            ocamlPkgs.yojson
            ocamlPkgs.sedlex
            ocamlPkgs.menhirLib
          ];
          checkInputs = [ ocamlPkgs.alcotest ];
          doCheck = true;
        };
      in
      {
        packages.default = beloch;
        packages.beloch = beloch;

        apps.default = {
          type = "app";
          program = "${beloch}/bin/beloch";
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [ beloch ];
          packages = [
            ocamlPkgs.ocaml
            ocamlPkgs.dune_3
            ocamlPkgs.findlib
            ocamlPkgs.menhir
            ocamlPkgs.menhirLib
            ocamlPkgs.sedlex
            ocamlPkgs.yojson
            ocamlPkgs.zarith
            ocamlPkgs.alcotest
            # tooling
            ocamlPkgs.ocaml-lsp
            ocamlPkgs.ocamlformat
            ocamlPkgs.utop
          ];
        };
      }
    );
}
