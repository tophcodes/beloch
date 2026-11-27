## REMOVED Requirements

### Requirement: A reverse fold folds without an outline
**Reason**: No write ranks its states by the outline any more (change `drop-outline-ranking`), so a reverse fold needs no exemption from it.
**Migration**: None. A reverse fold keeps its states whether or not they reach past the convex hull of the state before it, as before.
