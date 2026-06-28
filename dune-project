(lang dune 3.0)

(name beloch)

(package
 (name beloch)
 (synopsis "A declarative language for origami, built on the Huzita-Justin axioms")
 (depends
  ocaml
  dune
  menhir
  sedlex
  yojson
  ppx_deriving))
