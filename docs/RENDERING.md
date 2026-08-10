# Rendering and Security

## How the HTML is generated

`render_trace_html` keeps the original zero-dependency pipeline:

1. `AlgorithmTrace` is encoded as Trace Schema v1 JSON.
2. MoonBit uses `StringBuilder` to assemble one complete HTML document.
3. CSS, player JavaScript, and the escaped JSON payload are embedded inline.
4. The browser parses the JSON and renders the selected `Scene` locally.

The result is a single file with no server, framework, CDN, dynamic import, or
remote font. It can be opened directly from disk and archived with the trace.

Before embedding JSON, the renderer replaces `<` with its Unicode escape so a
label cannot close the data script element. Trace labels, values, attributes,
and annotations are inserted with `textContent`; trace data is never evaluated
as HTML. A no-network Content Security Policy provides an additional boundary.

## Interactive player

The v0.9 player defaults to Chinese and can switch its generated interface to
English. Adapter annotations remain unchanged so domain-specific text is not
silently translated. The layout is playback controls, current-event guide,
scene, annotation/pseudocode, statistics, and a complete highlight legend.

All eight `HighlightRole` values use separate background, border, text, and
visible role labels. Light and dark pairs are checked at a minimum 4.5:1 text
contrast. Stable entity IDs are hidden by default but can be displayed when a
trace author needs to inspect identity.

The browser derives a private event-guide model from each event and the scenes
before and after it:

- Compare names the compared targets and their positions or coordinates.
- Swap shows both index transitions and animates stable entities with FLIP.
- Update shows old value to new value and lists compared dependency states.
- Visit, Relax, and Union show the target or directional relationship.
- Complete makes the terminal state explicit.
- Custom events show their stable kind, attributes, and Adapter annotation.

Sequence scenes include an index axis. Grid scenes include row and column
coordinates. Graph arrows stop at node boundaries and deterministic layouts
animate through rotations. Set scenes expose changed memberships. Motion obeys
`prefers-reduced-motion`.

Generate representative files with:

```sh
moon run cmd/main -- demo insertion-sort --format html --output insertion-sort.html
moon run cmd/main -- demo knapsack --format html --output knapsack.html
moon run cmd/main -- demo lcs --format html --output lcs.html
moon run cmd/main -- demo red-black-tree --format html --output red-black-tree.html
```

Existing Schema v1 JSON can be rendered with:

```sh
moon run cmd/main -- render trace.json --format html --output trace.html
```

## SVG compatibility policy

`render_trace_svg` and `render_trace_svg_frames` are deprecated in v0.9. They
remain callable for compatibility, and CLI `--format svg` is marked legacy.
Both public APIs and the CLI SVG format are scheduled for removal in v1.0.
Use interactive HTML for visualization and Schema v1 JSON for interchange.

## AI Trace Clinic

`render_trace_playground()` creates a separate offline diagnostic workbench. It
accepts Schema v1 JSON by paste, file picker, or drag-and-drop and performs
browser-side validation, analysis, contracts, first-divergence diagnosis,
timeline replay, counterexample export, and diagnostic-report export.

The Clinic intentionally does not duplicate the v0.9 player's animation,
event-guide, or language systems. Its eight highlight roles use readable
foreground/background pairs, while the former “Export current SVG” title-card
button has been removed because it did not represent the actual scene.

Generate it with:

```sh
moon run cmd/main -- playground --output playground.html
```

Clinic applies a no-network CSP, a 20 MiB import limit, a 10,000-step limit,
and a 10,000-entity scene limit. It renders at most 101 timeline nodes around
the current focus while the slider still addresses the complete accepted
trace. Authoritative automation should use the MoonBit library or JSON CLI.
