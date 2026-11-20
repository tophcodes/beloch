---
id: ADR-0080
title: "A reviewed type states its contract in an interface, and the check holds the maintainer's hash of it"
date: 2026-11-19
status: proposed
issue: tophcodes/beloch#189
checks:
  - desc: Every reviewed interface matches the hash the maintainer recorded for it
    run: 'bash scripts/check-reviewed-interfaces.sh'
---

# ADR-0080: A reviewed type states its contract in an interface, and the check holds the maintainer's hash of it

## Context

The types of the kernel decide which states a program can reach. In the
petal fold of the traditional frog (tophcodes/beloch#189), the kernel kept
a ray of a fan as a crease and a direction on the table. The program had
named the ray on one layer, and the record held no layer and no point on
the paper, so the kernel scored the ray in every layer under it. In the
state the diagram draws, the top layer folds along a different line than
the layer below, and the kernel could not represent that state. The fold
failed with no flat state left. The type allowed a wrong value, and no
review caught it: the type lived inside an implementation file, which has
no interface a reviewer reads.

Agents write most of the code, and the maintainer reviews it. A type is
shorter than the code that uses it, and a changed type changes what every
caller can express, so the maintainer reviews types first. Today nothing
tells him when an agent changes a type he has already approved.

[[ADR-0018]] gave five modules an `.mli`, an OCaml interface file, which
lists the types and function signatures a module shows to other modules;
the compiler checks that the implementation file, the `.ml`, provides them. The
same record makes a type that crosses a module boundary abstract unless a
caller reads it. An abstract type appears in the `.mli` as its name alone,
so a reader of the interface does not see its definition.

## Decision

**A type the maintainer reviews is declared in an `.mli` with its full
definition.** Its doc comment states the condition every value of the type
meets.

**The form of the type excludes wrong shapes.** A variant has one case for
each shape a value may take. A record holds only fields that exist
together. A boolean flag or two independent options that admit a
combination with no meaning are replaced by a variant.

**A condition the form cannot carry is established by the functions of
the type's module.** Geometry is such a condition: every piece of a bundle
passes through the vertex of its fan. The type is declared `private`. Code
outside its module reads the fields and matches on the cases, and the
compiler refuses it to build a value. Only functions in the module build
values, and each of them establishes the condition: a parse function
builds a value from unchecked input and returns either the value or an
error, and a function that derives a value from valid ones shows that its
result meets the condition too. Tests for each of these functions accept
valid input and reject each kind of invalid input.

**A module stays small enough to review in one sitting.** A module that
declares a `private` type holds that type, the functions that build its
values and the functions that read them, and nothing else.

**The check holds a hash for each reviewed interface.** A list in the
repository records one SHA-256 hash per reviewed `.mli`. On every pull
request, the CI job `reviewed-interfaces` fails when a listed file no
longer matches its hash, and it stays red until the maintainer approves the
change by writing the new hash. The job runs apart from `check`, so its red
check tells him that the pull request waits for his review of an
interface. `check` and the other local steps leave the hashes alone, and an
agent works on a reviewed interface without being stopped before the
review. An agent writes the list only with his approval: a hook in the
repository's agent settings asks him before every call that writes the list,
and he approves the call once he has reviewed the change. A call that
reads the list passes the hook. An `.mli` that is not on the list has not
been reviewed. Implementation files carry no hash: their tests and their
size keep them reviewable.

**This record amends [[ADR-0018]] for reviewed types.** A reviewed type is
transparent or `private` in its interface. A type stays abstract only where
its representation may change without its callers noticing.

## Alternatives considered

- **A `CODEOWNERS` file with required review by code owners.** GitHub
  matches owners by path, and it counts no approval from the author of a
  pull request. The pull requests that agents prepare are opened under the
  maintainer's account, so the rule would block every one of them.
- **Comments that mark reviewed code.** The next edit leaves them in
  place whether or not it kept the reviewed form, and nothing checks them.
- **Abstract types, as [[ADR-0018]] decided.** They keep callers from
  building wrong values, and they hide the definition from the reader of
  the `.mli`, the one place the maintainer reviews.
- **Refinement or dependent types**, which state a condition in the type
  and let a checker prove it. OCaml has neither in its compiler. The
  kernel's conditions are geometry over exact algebraic numbers, and a
  proof for each of them would cost more than a parse function and its
  tests.
- **Hashes for implementation files as well.** Every change to an
  implementation would wait for the maintainer, while tests already decide
  whether the implementation meets its contract.

## Consequences

- The fans of `flatten` are the first case: the types that carry a fan's
  vertex and its bundles of creases (tophcodes/beloch#189) are written as a
  reviewed `.mli` before the kernel changes.
- The hash list starts empty and grows as the maintainer reviews
  interfaces. The check passes on an empty list.
- The compiler stops warning about an unused field or case of a reviewed
  type. It warns only when no code outside the module can read the field,
  and a transparent or `private` type lets every caller read it. This is
  the second reason [[ADR-0018]] gave for abstract types. A reviewed type
  is small and read in full during its review, where an unused field shows.
- A reviewed type moves out of the large implementation file that defines
  it today into a module of its own; a separate issue covers splitting the
  kernel into smaller modules.
- The hook reads a shell command as text. It asks for a redirection into
  the list and for the commands it knows to write a file. A command that
  assembles the path of the list instead of naming it, or writes through a
  command the hook does not know, passes the hook, and the CI job
  `reviewed-interfaces` catches the changed interface then.
- The hook guards the list alone. A change to the check, the hook or the
  agent settings is reviewed in its pull request like any other script.
