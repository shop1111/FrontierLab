# Contributing

Keep changes focused and preserve the stable trace schema. Public APIs need docstrings and black-box tests; renderer changes need escaping and deterministic-output tests.

Before opening a change, run:

```bash
moon check --target all --deny-warn
moon build --target all --deny-warn
moon fmt --check
moon info
git diff --exit-code
moon test --target all --deny-warn
moon package
```

Run `git diff --exit-code` after `moon info` only on a clean committed tree or in CI. During local development, review the generated `pkg.generated.mbti` diff instead.

Examples must run offline. Do not add CDN dependencies to generated HTML. Third-party code, fixtures, or generated assets must document their source and license.
