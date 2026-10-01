(lang dune 3.0)

(using menhir 2.1)

(name beloch)

(package
 (name beloch)
 (synopsis "Origami folding sequences as programs")
 (depends
  ocaml
  dune
  menhir
  sedlex
  zarith
  yojson
  (alcotest :with-test)
  (qcheck-core :with-test)
  (qcheck-alcotest :with-test)))
