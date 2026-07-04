# Rendering and Security

`render_trace_html` creates one offline HTML document containing CSS, JavaScript, and trace JSON. It supports previous/next, playback, speed, a timeline, keyboard navigation, event counts, responsive layout, dark mode, and reduced-motion preferences.

Trace JSON replaces `<` with its Unicode escape before embedding, preventing user labels from closing the data script element. The player inserts all trace labels and annotations with `textContent`; it never evaluates trace data as HTML. SVG output escapes XML metacharacters.

The renderer uses no network resources, CDN scripts, dynamic imports, or remote fonts. Generated files can be reviewed, archived, taught from, and opened without a server.

`render_trace_svg(trace, step=...)` selects the initial scene with `-1` or a recorded zero-based step. `render_trace_svg_frames` returns every recorded frame for downstream GIF or video tooling.
