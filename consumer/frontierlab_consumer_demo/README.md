# FrontierLab published-package consumer

This directory is a standalone MoonBit project that depends on
`shop1111/frontierlab@0.7.1` from Mooncakes. It does not use a local path
override or copy FrontierLab source code.

It exists to simulate a real external user, verify that the published package
can be resolved and called, and provide a complete integration example. Normal
library users do not need to run this project.

After v0.7.1 is published, verify it with:

```sh
moon tree
moon check --target all --deny-warn
moon test --target all --deny-warn
moon run . -- evidence
```

`moon tree` must resolve exactly `shop1111/frontierlab@0.7.1`. The executable
creates an expected and an intentionally incorrect selection-sort trace. The
first difference is step 10, and the incorrect final sequence fails the sorting
rule.

Generated files are written under `evidence/`. That directory is ignored by
Git because the outputs can be reproduced from this source project.
