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

        # nixpkgs is still on flint 3.5.0; override to 3.6.0 for
        # `_qqbar_roots_poly_squarefree` (roots of polys with qqbar coeffs).
        flint = pkgs.flint3.overrideAttrs (old: {
          version = "3.6.0";
          src = pkgs.fetchurl {
            url = "https://github.com/flintlib/flint/releases/download/v3.6.0/flint-3.6.0.tar.gz";
            sha256 = "sha256-uV4sd5L17qShyNLULECYQ0dWgy5XoJSyletd/cm0w2s=";
          };
        });

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
            flint
          ];
          checkInputs = [ ocamlPkgs.alcotest ];
          # Tests run in the `checks` output (nix flake check / CI), not on every
          # `nix build .#` — the number-kernel suite (Sturm/resultant/RUR) is slow.
          doCheck = false;
        };
      in
      {
        packages.default = beloch;
        packages.beloch = beloch;

        # `nix flake check` builds this — same derivation, tests enabled.
        checks.default = beloch.overrideAttrs (_: { doCheck = true; });

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
            flint
            # FOLD -> SVG/PNG rendering (render/render-svg)
            pkgs.bun
          ];
        };
      }
    );
}
