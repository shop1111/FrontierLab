# FrontierLab published-package consumer

This nested module is an independent consumer of
`shop1111/frontierlab@0.6.0` from Mooncakes. It has no local path override,
copies no FrontierLab source, and calls only the published public API.

```sh
moon tree
moon check --target all --deny-warn
moon test --target all --deny-warn
moon run . -- evidence
```

The expected and faulty traces both implement selection sort over
`[5, 2, 4, 1, 3]`. At step 10 the correct trace swaps `item-2` (value 4) with
`item-4` (value 3). The faulty trace reuses stale index 3 and swaps `item-2`
with `item-0` (value 5). The first divergence is therefore deterministic at
step 10, and the final faulty sequence violates the integer sorting contract.

After FrontierLab 0.6.1 and 0.7.0 are actually published, update this dependency
one version at a time and regenerate the evidence. Until then, keeping 0.6.0 is
intentional proof that the demo does not depend on the parent working tree.
