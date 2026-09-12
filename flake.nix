{
  description = "Beloch — a declarative language for origami";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};
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
          nativeBuildInputs = [ocamlPkgs.menhir];
          buildInputs = [
            ocamlPkgs.zarith
            ocamlPkgs.yojson
            ocamlPkgs.sedlex
            ocamlPkgs.menhirLib
            flint
          ];
          checkInputs = [ocamlPkgs.alcotest];
          # msolve is a subprocess dependency (packages/multifold/lib/msolve.ml) for
          # tests only, so it belongs at test time (nativeCheckInputs), not linked in.
          nativeCheckInputs = [pkgs.msolve];
          # Tests run in the `checks` output (nix flake check / CI), not on every
          # `nix build .#` — the number-kernel suite (Sturm/resultant/RUR) is slow.
          doCheck = false;
        };
      in {
        packages.default = beloch;
        packages.beloch = beloch;

        # `nix flake check` builds this — same derivation, tests enabled.
        checks.default = beloch.overrideAttrs (_: {doCheck = true;});

        apps.default = {
          type = "app";
          program = "${beloch}/bin/beloch";
        };

        devShells.default = pkgs.mkShell {
          name = "beloch";
          inputsFrom = [beloch];
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
            # js_of_ocaml (packages/eval-web/) — browser eval bundle, rational fragment
            ocamlPkgs.js_of_ocaml
            ocamlPkgs.js_of_ocaml-compiler
            ocamlPkgs.zarith_stubs_js
            # tooling
            ocamlPkgs.ocaml-lsp
            ocamlPkgs.ocamlformat
            ocamlPkgs.utop
            flint
            # FOLD -> SVG/PNG rendering (packages/render-2d/render-svg)
            pkgs.bun
            # msolve subprocess driver (packages/multifold/lib/msolve.ml)
            pkgs.msolve
            # spec/MODEL.md -> PDF with citations from paper/references.bib
            # (scripts/render-model.sh); typst is pandoc's PDF engine here
            pkgs.pandoc
            pkgs.typst
          ];
          # Link @beloch/render-svg's `beloch-render` bin globally so the
          # OCaml `beloch render` subcommand (packages/core/bin/main.ml) can execvp it, and
          # shim a bare `beloch` onto PATH that always runs the freshly
          # built binary (not a stale Nix-store copy) via `dune exec`.
          shellHook = ''
            export PATH="$(bun pm bin -g 2>/dev/null):$PATH"
            root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
            ( cd "$root/packages/render-2d" && bun install --silent ) >/dev/null 2>&1
            ( cd "$root/packages/render-2d/render-svg" && bun link --silent ) >/dev/null 2>&1
            mkdir -p "$root/.direnv/bin"
            cat > "$root/.direnv/bin/beloch" <<EOF
#!/usr/bin/env bash
exec dune exec --display=quiet --root "$root" beloch -- "\$@"
EOF
            chmod +x "$root/.direnv/bin/beloch"
            export PATH="$root/.direnv/bin:$PATH"
          '';
        };
      }
    );
}
