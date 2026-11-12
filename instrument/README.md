# frontierlab-instrument

Line-by-line replay for [FrontierLab](https://github.com/shop1111/FrontierLab)
`explore`, without writing `mark` calls by hand.

The tool parses a MoonBit file with the official `moonbitlang/parser`, finds
every statement of the functions you name, and inserts
`@explore.auto_mark(VAR, LINE, "code")` before each one. When
`@explore.replay` (or `explore`) runs an operation that calls these functions,
every line becomes a step of the replay showing `VAR` just before that line
runs. `--remove` takes the calls out again and restores the file byte for byte.

```bash
frontierlab-instrument src/hashmap.mbt --fn HashMap::grow --watch wider
moon run src/main -- smallest.html     # every line of grow is now a step
frontierlab-instrument --remove src/hashmap.mbt
```

- `--fn NAME` names a function, `name` or `Type::name`; repeat it for more.
- `--watch VAR` (after an `--fn`) chooses the variable to record. By default
  it is the function's first parameter. A local is recorded only where it is
  in scope: after its `let`, or inside the loop that binds it.
- `--stdout` prints the instrumented source instead of changing the file.
- `--pkg ALIAS` is the name under which the file's package imports
  `shop1111/frontierlab/explore` (default `explore`). That package must import
  it in its `moon.pkg`; the tool warns when it does not.

Each mark goes on the line of the statement it precedes and carries that
line's number, so the replay shows the original line numbers even after
`moon fmt` moves the marks onto lines of their own. At most one mark goes on
each line, bodies of closures and local functions are skipped, and the
instrumented source is parsed again before it is written. Values recorded
need `ToJson`. At most 200 marks are kept for one step.

Build it from the repository with `moon build main --target native --release`
in this directory, or use `frontierlab-instrument.exe` from the GitHub release.
