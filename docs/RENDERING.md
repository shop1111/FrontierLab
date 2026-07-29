# Rendering and Security

`render_trace_html` creates one offline HTML document containing CSS, JavaScript, and trace JSON. It supports previous/next, playback, speed, a timeline, keyboard navigation, event counts, responsive layout, dark mode, and reduced-motion preferences.

Trace JSON replaces `<` with its Unicode escape before embedding, preventing user labels from closing the data script element. The player inserts all trace labels and annotations with `textContent`; it never evaluates trace data as HTML. SVG output escapes XML metacharacters.

The renderer uses no network resources, CDN scripts, dynamic imports, or remote fonts. Generated files can be reviewed, archived, taught from, and opened without a server.

`render_trace_svg(trace, step=...)` selects the initial scene with `-1` or a recorded zero-based step. `render_trace_svg_frames` returns every recorded frame for downstream GIF or video tooling.

`render_trace_playground()` creates an offline workbench that accepts schema-v1 JSON by paste, file picker, or drag-and-drop. It performs browser-side structural diagnostics, analysis, quality checks, timeline replay, and JSON/current-frame SVG export without uploading trace data or loading remote assets. Generate it with `moon run cmd/main -- playground --output playground.html`.

The local v0.7.0 candidate presents this workbench as **AI Trace Clinic**. Its
default frozen selection-sort case runs schema/contract checks, jumps to the
first divergence at step 10, explains stable-entity changes, and prepares a
minimal counterexample plus repair prompt in one click. A correct case proves
the no-false-positive path; custom input without an expected trace explicitly
skips divergence. Existing raw JSON, playback, filters, breakpoints, and speed
controls remain under Advanced details.

The hosted page remains v0.6.0 until a future Pages deployment. Browser checks
mirror the portable debugger concepts; authoritative automation should use the
MoonBit library or JSON CLI.
