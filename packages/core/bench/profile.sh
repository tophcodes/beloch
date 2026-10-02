#!/usr/bin/env bash
# Kernel profile: samples bench_fold under `perf` and writes, into OUTDIR
# (default _build/profile):
#
#   flamegraph.svg   where the time goes, call stacks merged by inferno
#   modules.svg      the module dependency graph of packages/core/lib, each
#                    module colored by its self time and labeled with its
#                    direct and transitive fan-in (modules that depend on it)
#   self-time.txt    self time grouped by kernel module and by library
#
#   bench/profile.sh [OUTDIR] [bench_fold case ...]
#
# The compiler is built without frame pointers, so `perf` cannot unwind past a
# call from OCaml into C (Zarith, GMP, FLINT): those stacks end at
# caml_c_call. Self time is exact; inclusive time in the flame graph is a
# lower bound.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT="$(realpath -m "${1:-$ROOT/_build/profile}")"
shift || true
cd "$ROOT"
mkdir -p "$OUT"

dune build packages/core/bench/bench_fold.exe packages/core/lib
EXE="$ROOT/_build/default/packages/core/bench/bench_fold.exe"
LIB="$ROOT/_build/default/packages/core/lib"

# 65528 bytes is the largest stack copy `perf` takes per sample; the default
# 8 KiB truncates most kernel stacks.
DUNE_SOURCEROOT="$ROOT" perf record -q -F 999 --call-graph dwarf,65528 \
  -o "$OUT/perf.data" "$EXE" "$@" >/dev/null
perf script -i "$OUT/perf.data" 2>/dev/null | inferno-collapse-perf > "$OUT/stacks.folded"
inferno-flamegraph --title "beloch kernel: bench_fold" < "$OUT/stacks.folded" > "$OUT/flamegraph.svg"

# Self time: the leaf frame of each folded stack, grouped. OCaml symbols carry
# a numeric suffix (Beloch.Poly.divmod_494).
awk '
  { n = $NF; $NF = ""; sub(/ $/, ""); k = split($0, f, ";"); s = f[k]
    if (s ~ /^Beloch\./)                     { split(s, p, "."); g = p[2] }
    else if (s ~ /^(Z\.|Q\.|ml_z_)/)         g = "[Zarith]"
    else if (s ~ /gmpn|gmpz|gmpq/)           g = "[GMP]"
    else if (s ~ /^(fmp|nmod|arb|acb|arf|mag|qqbar|n_|flint)/) g = "[FLINT]"
    else if (s ~ /^Stdlib/)                  g = "[Stdlib]"
    else if (s ~ /^(caml_|alloc_|compare_val|mark_|sweep|oldify)/) g = "[OCaml runtime, GC]"
    else                                     g = "[other]"
    t[g] += n; total += n }
  END { for (g in t) printf "%6.2f %s\n", 100 * t[g] / total, g }
' "$OUT/stacks.folded" | sort -rn > "$OUT/self-time.txt"

# Module graph from `ocamldep` over the build copies (they include the
# menhir-generated parser.ml; *.pp.ml hold a binary syntax tree).
ocamldep -modules $(ls "$LIB"/*.ml | grep -v '\.pp\.ml$') \
  | awk -v selfs="$OUT/self-time.txt" '
  BEGIN { while ((getline l < selfs) > 0) { split(l, w, " "); self[w[2]] = w[1] } }
  { m = $1; sub(/.*\//, "", m); sub(/\.ml:$/, "", m); m = toupper(substr(m, 1, 1)) substr(m, 2)
    mods[m] = 1; line[m] = $0 }
  END {
    for (m in mods) { k = split(line[m], u, " ")
      for (i = 2; i <= k; i++) if ((u[i] in mods) && u[i] != m) { dep[m "," u[i]] = 1; uses[m] = uses[m] " " u[i] } }
    for (a in mods) {
      direct = 0; for (b in mods) if ((b "," a) in dep) direct++
      delete r; r[a] = 1; changed = 1
      while (changed) { changed = 0
        for (b in mods) if (!(b in r)) { k = split(uses[b], u, " ")
          for (i = 1; i <= k; i++) if (u[i] in r) { r[b] = 1; changed = 1; break } } }
      trans = -1; for (b in r) trans++
      fin[a] = direct "/" trans }
    print "digraph modules {"
    print "  rankdir=BT; node [shape=box style=filled fontname=\"sans-serif\" fontsize=11];"
    print "  edge [color=\"#888888\" arrowsize=0.6];"
    print "  labelloc=t; label=\"packages/core/lib: a path from A to B means A depends on B; label: self time %, fan-in direct/transitive\";"
    for (m in mods) {
      s = (m in self) ? self[m] : 0
      # white at 0 %, full orange at 10 % self time and above
      x = s / 10; if (x > 1) x = 1
      printf "  %s [label=\"%s\\n%.1f %%  %s\" fillcolor=\"#%02x%02x%02x\"];\n", m, m, s, fin[m], 255, 255 - int(90 * x), 255 - int(255 * x)
    }
    for (e in dep) { split(e, p, ","); printf "  %s -> %s;\n", p[1], p[2] }
    print "}" }
' | tred > "$OUT/modules.dot"
dot -Tsvg "$OUT/modules.dot" > "$OUT/modules.svg"

cat "$OUT/self-time.txt" | head -15
echo "wrote $OUT/{flamegraph.svg,modules.svg,self-time.txt}" >&2
