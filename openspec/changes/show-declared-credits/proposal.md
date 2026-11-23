## Why

Beloch makes it cheap to write a model as a program and render it anew, and
a fresh rendering drops the credit of the model's designer unless something
carries it. A program declares its credits with `@author`, `@design` and
`@source`, and the FOLD file carries them, yet none of Beloch's own tools
shows them. When the playground, the document cards and the renderers show
declared credits by default, crediting the designer is the visible default,
and the MIT license still asks nothing of anyone.

## What Changes

- The playground, the document cards and the renderers this project ships
  show the credits a program declares, beside what they draw, without a
  setting turned on.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `architecture`: Beloch's own tools show declared credits by default.

## Impact

The playground and the document cards in `packages/www`, the renderers in
`packages/render-2d`. The kernel already writes the credits into the FOLD
file and stays as it is.
