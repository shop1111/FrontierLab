# Contributing

Keep changes focused and preserve the stable trace schema and existing pathfinding APIs. Public APIs need docstrings and black-box tests; renderer changes need escaping and deterministic-output tests.

Before opening a change, run:

```bash
moon check --target all
moon test
moon info
moon fmt
```

Examples must run offline. Do not add CDN dependencies to generated HTML. Third-party code, fixtures, or generated assets must document their source and license.
