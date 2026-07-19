#!/usr/bin/env bash
# Phase 0 spike: build GMP -> MPFR -> FLINT 3.6.0 as static libs for
# wasm32-emscripten, then compile+link check.c and run it under node.
#
# Proves: FLINT 3.6 (with Calcium/Arb/Antic/qqbar bundled in) compiles to
# wasm via emscripten, and qqbar_sqrt computes a numerically-correct
# algebraic sqrt(2) at runtime under node.
#
# Usage: run from anywhere; paths are relative to this script's directory.
#   ./build.sh
#
# Requires network access (downloads GMP/MPFR/FLINT release tarballs) and
# nix (for `nix shell nixpkgs#emscripten ...`).
set -euo pipefail

SPIKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SPIKE_DIR/src"
PREFIX="$SPIKE_DIR/prefix"

GMP_VERSION=6.3.0
MPFR_VERSION=4.2.1
FLINT_VERSION=3.6.0
# sha256 pinned in /home/toph/Projects/beloch/flake.nix for the flint override
FLINT_SHA256=b95e2c7792f5eea4a1c8d2d42c4098434756832e57a094b295eb5dfdc9b4c36b

NIX_PKGS="nixpkgs#emscripten nixpkgs#m4 nixpkgs#gnumake nixpkgs#autoconf nixpkgs#automake nixpkgs#gcc"

mkdir -p "$SRC_DIR" "$PREFIX"

# ---------------------------------------------------------------------------
# 1. Download + extract sources
# ---------------------------------------------------------------------------
cd "$SRC_DIR"

if [ ! -f "gmp-$GMP_VERSION.tar.xz" ]; then
  curl -sL -o "gmp-$GMP_VERSION.tar.xz" "https://gmplib.org/download/gmp/gmp-$GMP_VERSION.tar.xz"
fi
if [ ! -f "mpfr-$MPFR_VERSION.tar.xz" ]; then
  curl -sL -o "mpfr-$MPFR_VERSION.tar.xz" "https://www.mpfr.org/mpfr-$MPFR_VERSION/mpfr-$MPFR_VERSION.tar.xz"
fi
if [ ! -f "flint-$FLINT_VERSION.tar.gz" ]; then
  curl -sL -o "flint-$FLINT_VERSION.tar.gz" "https://github.com/flintlib/flint/releases/download/v$FLINT_VERSION/flint-$FLINT_VERSION.tar.gz"
fi

echo "$FLINT_SHA256  flint-$FLINT_VERSION.tar.gz" | sha256sum -c -

[ -d "gmp-$GMP_VERSION" ]   || tar xf "gmp-$GMP_VERSION.tar.xz"
[ -d "mpfr-$MPFR_VERSION" ] || tar xf "mpfr-$MPFR_VERSION.tar.xz"
[ -d "flint-$FLINT_VERSION" ] || tar xf "flint-$FLINT_VERSION.tar.gz"

# ---------------------------------------------------------------------------
# 2. GMP
# ---------------------------------------------------------------------------
if [ -f "$PREFIX/lib/libgmp.a" ]; then
  echo "=== GMP already built, skipping ==="
else
  echo "=== building GMP ==="
  cd "$SRC_DIR/gmp-$GMP_VERSION"
  nix shell $NIX_PKGS --command bash -c "
  set -e
  export CC_FOR_BUILD=gcc
  emconfigure ./configure --host=none --disable-assembly --enable-static --disable-shared --prefix='$PREFIX'
  emmake make -j\$(nproc)
  emmake make install
  "
fi

# ---------------------------------------------------------------------------
# 3. MPFR
# ---------------------------------------------------------------------------
if [ -f "$PREFIX/lib/libmpfr.a" ]; then
  echo "=== MPFR already built, skipping ==="
else
  echo "=== building MPFR ==="
  cd "$SRC_DIR/mpfr-$MPFR_VERSION"
  nix shell $NIX_PKGS --command bash -c "
  set -e
  export CC_FOR_BUILD=gcc
  emconfigure ./configure --host=none --with-gmp='$PREFIX' --enable-static --disable-shared --prefix='$PREFIX'
  emmake make -j\$(nproc)
  emmake make install
  "
fi

# ---------------------------------------------------------------------------
# 4. FLINT 3.6.0
#
# NOTE the load-bearing --host=none: without it, FLINT's own configure.ac
# autodetects the *native build machine* as host (emconfigure only swaps
# CC/AR/RANLIB, it does not infer --host), which routes configure into its
# X86_64_PATTERN branch. That branch probes assembler label-suffix
# conventions (GMP_ASM_LABEL_SUFFIX, for longlong_asm_gnu.h) even with
# --disable-assembly, and that probe assembles raw x86-style asm text with
# emcc/clang targeting wasm32 -- which fails ("Cannot determine label
# suffix"). --host=none (matching GMP/MPFR) avoids that branch entirely.
# ---------------------------------------------------------------------------
if [ -f "$PREFIX/lib/libflint.a" ]; then
  echo "=== FLINT already built, skipping ==="
else
  echo "=== building FLINT ==="
  cd "$SRC_DIR/flint-$FLINT_VERSION"
  nix shell $NIX_PKGS --command bash -c "
  set -e
  export CC_FOR_BUILD=gcc
  emconfigure ./configure --host=none --disable-assembly --disable-pthread --without-blas --with-gmp='$PREFIX' --with-mpfr='$PREFIX' --enable-static --disable-shared --prefix='$PREFIX'
  emmake make -j\$(nproc)
  emmake make install
  "
fi

# ---------------------------------------------------------------------------
# 5. Compile + link the proof program, run it under node
# ---------------------------------------------------------------------------
echo "=== compiling check.c to wasm ==="
cd "$SPIKE_DIR"
nix shell nixpkgs#emscripten --command bash -c "
emcc check.c -I'$PREFIX/include' -L'$PREFIX/lib' -lflint -lmpfr -lgmp -o check.js -sEXPORTED_RUNTIME_METHODS=ccall -sERROR_ON_UNDEFINED_SYMBOLS=0
"

echo "=== running check.js under node (expect 1.41421356) ==="
node check.js

# ---------------------------------------------------------------------------
# 6. Phase 1: link web/qqbar_wasm.c (the flat-ABI shim) into a MODULARIZE'd,
#    SINGLE_FILE emscripten module — this is the real qqbar backend for the
#    js_of_ocaml bundle, not a throwaway check.
# ---------------------------------------------------------------------------
WEB_DIR="$(cd "$SPIKE_DIR/../packages/eval-web" && pwd)"
OUT_DIR="$(cd "$SPIKE_DIR/.." && pwd)/packages/www/public/beloch"
mkdir -p "$OUT_DIR"

WASM_QQBAR_FUNCS="_wasm_qqbar_alloc,_wasm_qqbar_free,_wasm_free_str,\
_wasm_qqbar_of_q,_wasm_qqbar_to_q_str,_wasm_qqbar_is_rational,_wasm_qqbar_is_zero,\
_wasm_qqbar_neg,_wasm_qqbar_inv,_wasm_qqbar_sqrt,\
_wasm_qqbar_add,_wasm_qqbar_sub,_wasm_qqbar_mul,_wasm_qqbar_div,\
_wasm_qqbar_equal,_wasm_qqbar_cmp_re,_wasm_qqbar_sgn_re,_wasm_qqbar_degree,\
_wasm_qqbar_get_d,_wasm_qqbar_minpoly,_wasm_qqbar_express_in_field,\
_wasm_qqbar_enclosure,_wasm_qqbar_real_roots,_wasm_qqbar_roots_qqbar_poly,\
_malloc,_free"

# GROWABLE_ARRAYBUFFERS=0 is load-bearing: emscripten 6's default (1) makes the
# heap views sit on a *resizable* ArrayBuffer (wasmMemory.toResizableBuffer()).
# Firefox's TextDecoder.decode rejects views backed by resizable buffers, so any
# FLINT string result marshalled via UTF8ToString throws a TypeError in Firefox.
# =0 keeps ALLOW_MEMORY_GROWTH (on-demand growth) but via classic copy-on-grow
# into a fresh non-resizable buffer — no upfront reservation, cross-browser safe.
#
# EMULATE_FUNCTION_POINTER_CASTS=1 is also load-bearing: FLINT's
# qqbar_express_in_field calls a function pointer whose C signature is cast (UB
# that native ignores but wasm's typed call_indirect rejects), so the routing
# added in #57 (compute in-field +/* over ℚ(α)) trapped with "indirect call
# signature mismatch" / "null function" in ALL engines — every √2-class fold in
# the playground died once #57 started calling it. =1 routes indirect calls
# through signature-adapting thunks, restoring correct behaviour.
echo "=== compiling web/qqbar_wasm.c to site/public/beloch/qqbar-wasm.js ==="
nix shell nixpkgs#emscripten --command bash -c "
emcc '$WEB_DIR/qqbar_wasm.c' -I'$PREFIX/include' -L'$PREFIX/lib' -lflint -lmpfr -lgmp \
  -O2 -sWASM_ASYNC_COMPILATION=0 -sMODULARIZE=1 -sEXPORT_NAME=QqbarWasm -sSINGLE_FILE=1 \
  -sEXPORTED_FUNCTIONS='$WASM_QQBAR_FUNCS' \
  -sEXPORTED_RUNTIME_METHODS=ccall,cwrap,UTF8ToString,stringToUTF8,lengthBytesUTF8 \
  -sALLOW_MEMORY_GROWTH=1 -sGROWABLE_ARRAYBUFFERS=0 \
  -sEMULATE_FUNCTION_POINTER_CASTS=1 \
  -o '$OUT_DIR/qqbar-wasm.js'
"
ls -la "$OUT_DIR/qqbar-wasm.js"
