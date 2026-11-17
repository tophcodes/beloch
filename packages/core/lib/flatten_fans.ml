(** `flatten` over fan items: several vertices folded in one motion
    (ADR 0055). *)

let run (_ctx : Ctx.ctx) ~into:_ ~bind_out:_ ~fans:_ ~overs:_ ~staying_opt:_
    ~on_opt:_ ~toward_opt:_ (span : Error.span) : unit =
  Error.fail span "flatten with fan items is not implemented"
