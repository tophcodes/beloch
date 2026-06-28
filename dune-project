(lang dune 3.0)

(using menhir 2.1)

(name beloch)

(package
 (name beloch)
 (synopsis "A declarative language for origami, built on the Huzita-Justin axioms")
 (depends
  ocaml
  dune
  menhir
  sedlex
  zarith
  yojson
  (alcotest :with-test)))
