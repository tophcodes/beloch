## ADDED Requirements

### Requirement: A glossary entry states the kind of its term
Every glossary entry SHALL carry the kind of object its term is, as an RDF class that is a subclass of `bm:Term`: `structure`, `value`, `read`, `write` or `relation`. Where the term has a signature, the entry SHALL state it, with partiality marked. Introduced by the change glossary-term-kinds; its design gives the reason.

#### Scenario: A relation and a read
- **WHEN** a reader looks up alignment and selection in the glossary
- **THEN** the entry of alignment carries the class of a relation and the entry of selection the class of a read

#### Scenario: A total and a partial signature
- **WHEN** a reader looks up material and line in the glossary
- **THEN** material reads as total from a state and a table line to a bundle, and line as partial from a state and a bundle to a table line

### Requirement: The four terms of selection stand as definitions of their own
Alignment, construction, candidate and selection SHALL each stand as a definition of its own in `MODEL.md`, and the glossary entry of each SHALL link to its own definition. Introduced by the change glossary-term-kinds; its design gives the reason.

#### Scenario: The entry of candidate
- **WHEN** a reader follows the link of the glossary entry of candidate
- **THEN** it leads to a definition of candidate, and not to the definition of construction
