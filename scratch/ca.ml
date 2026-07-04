(* Spike: Calcium (ca_t) root-finding over algebraic coefficients.
   None when ca_poly_roots cannot split the polynomial in the field. *)
open Beloch

external ca_real_roots : Qqbar.t array -> Qqbar.t array option = "ml_ca_real_roots"
