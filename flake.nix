{
  description = "Beloch — origami folding sequences as programs";

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
          # Only the OCaml tree. A change to the docs, the site or the notes then
          # leaves the derivation untouched, and CI serves it from its cache.
          src = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.unions [
              ./dune
              ./dune-project
              ./packages/core
              ./packages/eval-web
            ];
          };
          duneVersion = "3";
          nativeBuildInputs = [ocamlPkgs.menhir];
          buildInputs = [
            ocamlPkgs.zarith
            ocamlPkgs.yojson
            ocamlPkgs.sedlex
            ocamlPkgs.menhirLib
            flint
          ];
          # qcheck: the property tests (packages/core/tests/test_prop_*.ml),
          # run as alcotest cases through qcheck-alcotest.
          checkInputs = [
            ocamlPkgs.alcotest
            ocamlPkgs.qcheck-core
            ocamlPkgs.qcheck-alcotest
          ];
          # msolve is a subprocess dependency of the separate research package, for
          # tests only, so it belongs at test time (nativeCheckInputs), not linked in.
          nativeCheckInputs = [pkgs.msolve];
          # Tests run in the `checks` output (nix flake check / CI), not on every
          # `nix build .#` — the number-kernel suite (Sturm/resultant/RUR) is slow.
          doCheck = false;
        };

        # Vale packages the prose lint (.vale.ini) reads, pinned here in place
        # of `vale sync`, which fetches them unpinned.
        valeStyles = {
          Slop = "${pkgs.fetchFromGitHub {
            owner = "Syntaf";
            repo = "vale-llm-slop";
            rev = "4dda3ec6426efa219e493d88396ed5c0471f7454";
            hash = "sha256-4B07P6W1bMRjelFVajWB54+G1NzK4j0Z5KKfSZ1+tfU=";
          }}/styles/Slop";
          proselint = "${pkgs.fetchFromGitHub {
            owner = "errata-ai";
            repo = "proselint";
            rev = "v0.3.4";
            hash = "sha256-ryKJDX1JrvDWVKLC5qQGctweDf74yuwEXxl/IqumM4s=";
          }}/proselint";
          write-good = "${pkgs.fetchFromGitHub {
            owner = "errata-ai";
            repo = "write-good";
            rev = "v0.4.1";
            hash = "sha256-W/eHlXklAVlAnY8nLPi/SIKsg8UUnH8UkH99BDo5yKk=";
          }}/write-good";
        };
        # Links the pinned packages into .vale/styles and the Hunspell dictionary
        # that Beloch.Spelling reads (.vale/styles/Beloch/Spelling.yml) into
        # .vale/dictionaries; git ignores both.
        linkValeStyles = ''
          root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
          ln -sfn ${pkgs.hunspellDicts.en_US-large}/share/hunspell "$root/.vale/dictionaries"
          ${pkgs.lib.concatStrings (pkgs.lib.mapAttrsToList (name: path: ''
              ln -sfn ${path} "$root/.vale/styles/${name}"
            '')
            valeStyles)}
        '';
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
            ocamlPkgs.qcheck-core
            ocamlPkgs.qcheck-alcotest
            # js_of_ocaml (packages/eval-web/) — browser eval bundle, rational fragment
            ocamlPkgs.js_of_ocaml
            ocamlPkgs.js_of_ocaml-compiler
            ocamlPkgs.zarith_stubs_js
            # tooling
            ocamlPkgs.ocaml-lsp
            ocamlPkgs.ocamlformat
            ocamlPkgs.odoc
            ocamlPkgs.utop
            flint
            # FOLD -> SVG/PNG rendering (packages/render-2d/render-svg)
            pkgs.bun
            # msolve subprocess driver (separate research package)
            pkgs.msolve
            # docs/reference/MODEL.md -> PDF with citations from bibliography/references.bib
            # (scripts/render-model.sh); typst is pandoc's PDF engine here
            pkgs.pandoc
            pkgs.typst
            # the `generate` script of packages/grammar, which rebuilds the
            # committed parser and wasm
            pkgs.tree-sitter
            # prose lint (.vale.ini, scripts/prose.sh)
            pkgs.vale
            # kernel profile (packages/core/bench/profile.sh)
            pkgs.inferno
            pkgs.graphviz
          ]
          ++ pkgs.lib.optionals pkgs.stdenv.isLinux [pkgs.perf];
          # `check`, `check-all` and `prose` run the script of that name in scripts/.
          # Shim `beloch` and `beloch-render` onto PATH from this checkout:
          # `beloch` runs the freshly built binary (not a stale Nix-store
          # copy) via `dune exec`, and `beloch-render`, which the OCaml
          # `beloch render` subcommand (packages/core/bin/main.ml) execvps,
          # runs this checkout's @beloch/render-svg CLI. Both live in the
          # workspace's own .direnv/bin, so jj workspaces open side by side
          # each run their own code, where a global `bun link` would point
          # every shell at the workspace that entered last.
          shellHook = ''
            root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
            ( cd "$root/packages/render-2d" && bun install --silent ) >/dev/null 2>&1
            mkdir -p "$root/.direnv/bin"
            cat > "$root/.direnv/bin/beloch" <<EOF
#!/usr/bin/env bash
exec dune exec --display=quiet --root "$root" beloch -- "\$@"
EOF
            chmod +x "$root/.direnv/bin/beloch"
            cat > "$root/.direnv/bin/beloch-render" <<EOF
#!/usr/bin/env bash
exec bun "$root/packages/render-2d/cli/bin/fold2svg.ts" "\$@"
EOF
            chmod +x "$root/.direnv/bin/beloch-render"
            ${linkValeStyles}
            for c in check check-all prose; do
              printf '#!/usr/bin/env bash\nexec "%s/scripts/%s.sh" "$@"\n' "$root" "$c" > "$root/.direnv/bin/$c"
              chmod +x "$root/.direnv/bin/$c"
            done
            export PATH="$root/.direnv/bin:$PATH"
          '';
        };

        # The prose lint for the pull request job in .github/workflows/prose.yml:
        # Vale, bun and the compiler and dune for the comment maskers, without
        # FLINT.
        devShells.prose = pkgs.mkShell {
          name = "beloch-prose";
          packages = [pkgs.vale pkgs.jq pkgs.bun ocamlPkgs.ocaml ocamlPkgs.dune_3];
          shellHook = linkValeStyles;
        };
      }
    );
}
