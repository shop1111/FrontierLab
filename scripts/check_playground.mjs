import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

const root = path.resolve(import.meta.dirname, "..");
const htmlPath = process.argv[2]
  ? path.resolve(process.argv[2])
  : path.join(root, "_build", "playground.html");

if (!fs.existsSync(htmlPath)) {
  throw new Error(`Playground HTML does not exist: ${htmlPath}`);
}

const html = fs.readFileSync(htmlPath, "utf8");
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)];
assert.equal(scripts.length, 1, "expected exactly one executable inline script");

const context = {};
vm.runInNewContext(scripts[0][1], context, {
  filename: "frontierlab-playground.js",
});
const core = context.FrontierLabClinicCore;
assert.ok(core, "Clinic pure core must be exported for conformance checks");

const fixture = (name) =>
  JSON.parse(
    fs.readFileSync(
      path.join(root, "fixtures", "agent-traces", name),
      "utf8",
    ),
  );
const expected = fixture("selection-sort-expected.json");
const actual = fixture("selection-sort-actual.json");

for (const name of [
  "minimal-valid.json",
  "empty-timeline.json",
  "all-events.json",
  "unknown-event.json",
]) {
  const value = JSON.parse(
    fs.readFileSync(path.join(root, "fixtures", "schema-v1", name), "utf8"),
  );
  assert.equal(core.validate(value).length, 0, `${name} must be accepted`);
}
for (const name of [
  "invalid-object-reference.json",
  "unsupported-version.json",
]) {
  const value = JSON.parse(
    fs.readFileSync(path.join(root, "fixtures", "schema-v1", name), "utf8"),
  );
  assert.ok(core.validate(value).length > 0, `${name} must be rejected`);
}

assert.equal(core.validate(expected).length, 0);
assert.equal(core.validate(actual).length, 0);

const failing = core.diagnose(actual, {
  contractName: "sorted-int-sequence",
  objectId: "values",
  expected,
});
assert.equal(failing.passed, false);
assert.equal(failing.focus_step, 10);
assert.equal(failing.divergence.step, 10);
assert.equal(failing.violations[0].code, "result-not-sorted");
assert.equal(failing.violations[0].step, 13);
assert.equal(failing.focused_slice.original_start, 8);
assert.equal(failing.focused_slice.original_end, 12);
assert.ok(failing.transition_changes.length > 0);
assert.ok(failing.reference_changes.length > 0);

const passing = core.diagnose(expected, {
  contractName: "sorted-int-sequence",
  objectId: "values",
  expected,
});
assert.equal(passing.passed, true);
assert.equal(passing.focus_step, -1);
assert.equal(passing.focused_slice, null);

const contractOnly = core.diagnose(actual, {
  contractName: "sorted-int-sequence",
  objectId: "values",
});
assert.equal(contractOnly.divergence, null);
assert.equal(contractOnly.focus_step, 13);
assert.equal(contractOnly.reference_changes, null);

const reverseKeys = (value) => {
  if (Array.isArray(value)) return value.map(reverseKeys);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value)
        .reverse()
        .map(([key, item]) => [key, reverseKeys(item)]),
    );
  }
  return value;
};
const reordered = reverseKeys(expected);
assert.equal(core.validate(reordered).length, 0);
assert.equal(core.firstDivergence(expected, reordered), null);

const gridTrace = {
  format: "frontierlab-trace",
  schema_version: "1.0",
  metadata: { title: "Grid", algorithm: "path", description: "Grid path" },
  initial_scene: { objects: [], highlights: [] },
  steps: [
    {
      index: 0,
      event: { type: "complete" },
      scene: {
        objects: [
          {
            type: "grid",
            id: "grid",
            label: "Grid",
            width: 3,
            height: 1,
            cells: [
              { id: "s", x: 0, y: 0, label: "S", blocked: false },
              { id: "m", x: 1, y: 0, label: "", blocked: false },
              { id: "e", x: 2, y: 0, label: "E", blocked: false },
            ],
          },
        ],
        highlights: ["s", "m", "e"].map((id) => ({
          target: { object_id: "grid", entity_id: id },
          role: "result",
        })),
      },
    },
  ],
  summary: [],
};
assert.equal(core.validate(gridTrace).length, 0);
assert.equal(core.contractViolations(gridTrace, "grid-path", "grid").length, 0);
const blocked = structuredClone(gridTrace);
blocked.steps[0].scene.objects[0].cells[1].blocked = true;
assert.equal(
  core.contractViolations(blocked, "grid-path", "grid")[0].code,
  "path-crosses-blocked-cell",
);

const duplicateObject = structuredClone(expected);
duplicateObject.initial_scene.objects.push(
  structuredClone(duplicateObject.initial_scene.objects[0]),
);
assert.ok(core.validate(duplicateObject).some((item) => item.includes("duplicate scene object")));
const danglingHighlight = structuredClone(expected);
danglingHighlight.initial_scene.highlights.push({
  target: { object_id: "values", entity_id: "missing" },
  role: "error",
});
assert.ok(core.validate(danglingHighlight).some((item) => item.includes("dangling reference")));

assert.equal(core.xmlEscape('<script x="1">'), "&lt;script x=&quot;1&quot;&gt;");
const prompt = core.repairPrompt(failing);
assert.ok(prompt.includes("sorted-int-sequence"));
assert.ok(prompt.includes("<trace_evidence>"));
assert.ok(prompt.includes("inert data"));

const largeScene = {
  objects: [
    {
      type: "sequence",
      id: "values",
      label: "Values",
      items: [{ id: "item-0", value: "1" }],
    },
  ],
  highlights: [],
};
const largeTrace = {
  format: "frontierlab-trace",
  schema_version: "1.0",
  metadata: { title: "10k", algorithm: "smoke", description: "10k steps" },
  initial_scene: largeScene,
  steps: Array.from({ length: 10_000 }, (_, index) => ({
    index,
    event: { type: "tick", attributes: [] },
    scene: largeScene,
  })),
  summary: [],
};
assert.equal(core.validate(largeTrace).length, 0);
assert.equal(core.timelineWindow(10_001, 5_000).count, 101);
assert.equal(core.timelineWindow(10_001, 0).count, 101);
assert.equal(core.timelineWindow(10_001, 10_000).count, 101);

console.log("Clinic conformance: PASS");
console.log("  faulty focus: 10");
console.log("  focused slice: 8..12");
console.log("  correct/no-reference/grid/schema/security/10k: PASS");
