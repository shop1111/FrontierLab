# FrontierLab published-package consumer

This directory is a standalone MoonBit project that depends on
`shop1111/frontierlab@0.12.0` from Mooncakes. It does not use a local path
override or copy FrontierLab source code.

It plays the part of an external user who has written their own data
structure and wants to find a bug in it. Normal library users do not need to
run this project.

## The user's code

[heap.mbt](heap.mbt) is an ordinary array-backed binary min-heap with `push`
and `pop`. The only FrontierLab-specific detail is `derive(ToJson)` on the
`Heap` struct. `pop` has a bug: during sift-down it compares only the left
child, so a smaller right child can end up below a larger parent.
`pop_fixed` is the corrected version. `heap_violation` is the property that
must hold after every operation.

## Verify a release

```sh
moon tree
moon check --target all --deny-warn
moon test --target all --deny-warn
moon run . -- evidence
```

`moon tree` must resolve exactly `shop1111/frontierlab@0.12.0`. The
executable does three things:

1. `explore` searches random `push`/`pop` sequences, finds the bug, and
   shrinks it to five steps: `push 0, push 1, push 0, push 1, pop`.
2. `replay` runs the hand-written input
   `push 1, push 5, push 2, push 6, push 7, pop` and reports that step 6
   leaves parent 5 above child 2.
3. `explore` runs again with `pop_fixed` and finds no failing sequence.

It writes two offline replay pages, `heap-explore.html` and
`heap-replay.html`, under `evidence/`. That directory is ignored by Git
because the outputs can be reproduced from this source project.
