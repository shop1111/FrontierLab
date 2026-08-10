import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

const root = path.resolve(import.meta.dirname, "..");
const htmlPath = process.argv[2]
  ? path.resolve(process.argv[2])
  : path.join(root, "_build", "renderer", "insertion-sort.html");

if (!fs.existsSync(htmlPath)) {
  throw new Error(`Renderer HTML does not exist: ${htmlPath}`);
}

const html = fs.readFileSync(htmlPath, "utf8");
const traceMatch = html.match(
  /<script id="trace-data" type="application\/json">([\s\S]*?)<\/script>/,
);
assert.ok(traceMatch, "expected embedded trace JSON");
const trace = JSON.parse(traceMatch[1]);
assert.ok(html.startsWith("<!doctype html>"));
assert.ok(html.includes('lang="zh-CN"'));
assert.ok(html.includes('id="guide"'));
assert.ok(html.includes('id="language"'));
assert.ok(html.includes('id="legend"'));
assert.ok(html.includes("data-entity-key"));
assert.ok(html.includes("grid-shell"));
assert.ok(html.includes("node.animate"));
assert.ok(html.includes("prefers-reduced-motion"));
assert.ok(html.includes("shortenedLine"));
assert.ok(html.includes("binaryTreeLayout"));
assert.ok(html.includes('data-tree-color'));
assert.ok(html.includes("--rb-red-bg"));
assert.ok(html.includes("--rb-black-bg"));
assert.ok(!html.includes("<script src="));
assert.ok(!html.includes("<link rel="));
assert.ok(!html.includes("https://"));

const executableScripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)];
assert.equal(executableScripts.length, 1, "expected one executable inline script");
const context = {};
vm.runInNewContext(executableScripts[0][1], context, {
  filename: "frontierlab-player.js",
});
const core = context.FrontierLabPlayerCore;
assert.ok(core, "player pure core must be exported");
assert.deepEqual(
  [...core.ROLES],
  [
    "current",
    "candidate",
    "compared",
    "changed",
    "visited",
    "frontier",
    "result",
    "error",
  ],
);

const sequence = (items, highlights = []) => ({
  objects: [
    {
      type: "sequence",
      id: "values",
      label: "Values",
      items,
    },
  ],
  highlights,
});
const target = (entity_id) => ({ object_id: "values", entity_id });
const before = sequence([
  { id: "a", value: "3" },
  { id: "b", value: "1" },
]);
const afterSwap = sequence([
  { id: "b", value: "1" },
  { id: "a", value: "3" },
]);

const compareZh = core.eventGuide(
  { type: "compare", targets: [target("a"), target("b")] },
  before,
  before,
  null,
  "zh",
);
assert.equal(compareZh.title, "比较");
assert.ok(compareZh.body.includes("索引 0"));
assert.ok(compareZh.body.includes("索引 1"));
const compareEn = core.eventGuide(
  { type: "compare", targets: [target("a"), target("b")] },
  before,
  before,
  null,
  "en",
);
assert.equal(compareEn.title, "Compare");
assert.ok(compareEn.body.includes("index 0"));

const swap = core.eventGuide(
  { type: "swap", left: target("a"), right: target("b") },
  before,
  afterSwap,
  null,
  "zh",
);
assert.equal(swap.title, "交换");
assert.equal(
  JSON.stringify(swap.motion.map(({ key, from, to }) => ({ key, from, to }))),
  JSON.stringify([
    { key: "values::a", from: 0, to: 1 },
    { key: "values::b", from: 1, to: 0 },
  ]),
);

const afterUpdate = sequence(
  [
    { id: "a", value: "4" },
    { id: "b", value: "1" },
  ],
  [
    { target: target("a"), role: "changed" },
    { target: target("b"), role: "compared" },
  ],
);
const update = core.eventGuide(
  { type: "update", target: target("a"), value: "4" },
  before,
  afterUpdate,
  null,
  "en",
);
assert.equal(update.title, "Update");
assert.equal(update.motion[0].from, "3");
assert.equal(update.motion[0].to, "4");
assert.equal(update.dependencies[0].key, "values::b");

const beforeVisit = sequence(
  [
    { id: "a", value: "3" },
    { id: "b", value: "1" },
  ],
  [{ target: target("a"), role: "current" }],
);
const visit = core.eventGuide(
  { type: "visit", target: target("b") },
  beforeVisit,
  sequence(
    [
      { id: "a", value: "3" },
      { id: "b", value: "1" },
    ],
    [{ target: target("b"), role: "current" }],
  ),
  null,
  "zh",
);
assert.equal(visit.motion[0].direction, true);
assert.ok(visit.body.includes("→"));

const annotatedVisit = core.eventGuide(
  { type: "visit", target: target("a") },
  before,
  before,
  { title: "查找键 3", body: "将键 3 与节点 3 比较。" },
  "zh",
);
assert.equal(annotatedVisit.title, "查找键 3");
assert.equal(annotatedVisit.body, "将键 3 与节点 3 比较。");

const relax = core.eventGuide(
  { type: "relax", from: target("a"), to: target("b"), value: "7" },
  before,
  before,
  null,
  "en",
);
assert.equal(relax.motion[0].direction, true);
assert.equal(relax.motion[0].value, "7");

const custom = core.eventGuide(
  { type: "rb-rotate-left", attributes: [{ key: "pivot", value: "20" }] },
  before,
  before,
  { title: "Rotate left", body: "Promote the right child." },
  "en",
);
assert.equal(custom.title, "Rotate left");
assert.equal(custom.attributes[0].value, "20");

const treeBefore = {
  objects: [
    {
      type: "graph",
      id: "tree",
      label: "红黑树结构",
      nodes: [{ id: "node-0", label: "30 [B]" }],
      edges: [],
    },
  ],
  highlights: [],
};
const treeAfter = {
  objects: [
    {
      type: "graph",
      id: "tree",
      label: "红黑树结构",
      nodes: [
        { id: "node-0", label: "30 [B]" },
        { id: "node-1", label: "10 [R]" },
      ],
      edges: [
        {
          id: "edge-node-0-node-1",
          from: "node-0",
          to: "node-1",
          label: "left",
          directed: true,
        },
      ],
    },
  ],
  highlights: [
    { target: { object_id: "tree", entity_id: "node-1" }, role: "changed" },
  ],
};
const insertGuide = core.eventGuide(
  {
    type: "rb-insert",
    attributes: [
      { key: "key", value: "10" },
      { key: "parent", value: "30" },
      { key: "direction", value: "left" },
    ],
  },
  treeBefore,
  treeAfter,
  {
    title: "插入红色节点",
    body: "将键 10 作为节点 30 的左孩子插入，初始颜色为红色。",
  },
  "zh",
);
assert.equal(insertGuide.motion[0].from, "父节点 30");
assert.equal(insertGuide.motion[0].to, "左孩子 10 [R]");
assert.equal(insertGuide.motion[0].fromKey, "tree::node-0");
assert.equal(insertGuide.attributes[2].value, "左");
const leftLayout = core.graphLayout(treeAfter.objects[0]);
const leftRoot = leftLayout.points.find((point) => point.id === "node-0");
const leftChild = leftLayout.points.find((point) => point.id === "node-1");
assert.ok(leftChild.x < leftRoot.x, "left child must render left of its parent");

if (trace.metadata.algorithm === "red-black-tree") {
  const insertSteps = trace.steps.filter((step) => step.event.type === "rb-insert");
  assert.ok(
    insertSteps.some((step) => step.annotation.body.includes("左孩子")),
    "red-black-tree insertion must explain a left child",
  );
  assert.ok(
    insertSteps.some((step) => step.annotation.body.includes("右孩子")),
    "red-black-tree insertion must explain a right child",
  );
  assert.ok(
    insertSteps.some((step) =>
      step.event.attributes.some(
        (attribute) => attribute.key === "direction" && attribute.value === "left",
      ),
    ),
    "red-black-tree event must retain stable left direction data",
  );
  const secondGraph = insertSteps[1].scene.objects.find(
    (object) => object.type === "graph",
  );
  const secondLayout = core.graphLayout(secondGraph);
  const root30 = secondGraph.nodes.find((node) => node.label.startsWith("30 "));
  const child10 = secondGraph.nodes.find((node) => node.label.startsWith("10 "));
  assert.ok(
    secondLayout.points.find((point) => point.id === child10.id).x <
      secondLayout.points.find((point) => point.id === root30.id).x,
    "the second inserted node must appear left of the root",
  );
  assert.equal(
    secondLayout.points.find((point) => point.id === root30.id).x -
      secondLayout.points.find((point) => point.id === child10.id).x,
    128,
    "binary-tree branches should use the compact horizontal spacing",
  );
  const thirdStep = insertSteps[2];
  const thirdGraph = thirdStep.scene.objects.find((object) => object.type === "graph");
  const thirdLayout = core.graphLayout(thirdGraph);
  const parent10 = thirdGraph.nodes.find((node) => node.label.startsWith("10 "));
  const child20 = thirdGraph.nodes.find((node) => node.label.startsWith("20 "));
  assert.ok(
    thirdLayout.points.find((point) => point.id === child20.id).x >
      thirdLayout.points.find((point) => point.id === parent10.id).x,
    "the third inserted node must appear right of its parent",
  );
  const thirdGuide = core.eventGuide(
    thirdStep.event,
    trace.steps[thirdStep.index - 1].scene,
    thirdStep.scene,
    thirdStep.annotation,
    "zh",
  );
  assert.ok(thirdGuide.motion[0].to.startsWith("右孩子"));
  assert.equal(thirdGuide.motion[0].fromKey, `tree::${parent10.id}`);
  const firstRecolor = trace.steps.find((step) => step.event.type === "rb-recolor");
  const recolorGuide = core.eventGuide(
    firstRecolor.event,
    trace.steps[firstRecolor.index - 1]?.scene ?? trace.initial_scene,
    firstRecolor.scene,
    firstRecolor.annotation,
    "zh",
  );
  assert.ok(recolorGuide.motion.length > 0, "recolor must expose color changes");
  assert.ok(
    recolorGuide.motion.some(
      (motion) =>
        motion.valueChange &&
        ((motion.from === "红" && motion.to === "黑") ||
          (motion.from === "黑" && motion.to === "红")),
    ),
    "recolor guide must show the old and new colors",
  );
  const firstVisit = trace.steps.find((step) => step.event.type === "visit");
  assert.ok(firstVisit.annotation.title.includes("查找键"));
  assert.match(firstVisit.annotation.body, /将键 \d+ 与节点 \d+ 比较/);
}

const hexToRgb = (hex) =>
  [1, 3, 5].map((offset) => Number.parseInt(hex.slice(offset, offset + 2), 16));
const luminance = (hex) => {
  const channels = hexToRgb(hex).map((value) => {
    const normalized = value / 255;
    return normalized <= 0.04045
      ? normalized / 12.92
      : ((normalized + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2];
};
const contrast = (left, right) => {
  const [bright, dark] = [luminance(left), luminance(right)].sort((a, b) => b - a);
  return (bright + 0.05) / (dark + 0.05);
};
for (const role of core.ROLES) {
  const backgrounds = [...html.matchAll(new RegExp(`--${role}-bg:(#[0-9a-f]{6})`, "gi"))].map(
    (match) => match[1],
  );
  const foregrounds = [...html.matchAll(new RegExp(`--${role}-fg:(#[0-9a-f]{6})`, "gi"))].map(
    (match) => match[1],
  );
  assert.equal(backgrounds.length, 2, `${role} needs light and dark backgrounds`);
  assert.equal(foregrounds.length, 2, `${role} needs light and dark foregrounds`);
  for (let mode = 0; mode < 2; mode += 1) {
    assert.notEqual(backgrounds[mode], foregrounds[mode], `${role} text must remain visible`);
    assert.ok(
      contrast(backgrounds[mode], foregrounds[mode]) >= 4.5,
      `${role} mode ${mode} contrast must be at least 4.5:1`,
    );
  }
}
for (const palette of ["rb-red", "rb-black"]) {
  const backgrounds = [
    ...html.matchAll(new RegExp(`--${palette}-bg:(#[0-9a-f]{6})`, "gi")),
  ].map((match) => match[1]);
  const foregrounds = [
    ...html.matchAll(new RegExp(`--${palette}-fg:(#[0-9a-f]{6})`, "gi")),
  ].map((match) => match[1]);
  assert.equal(backgrounds.length, 2, `${palette} needs light and dark backgrounds`);
  assert.equal(foregrounds.length, 2, `${palette} needs light and dark foregrounds`);
  for (let mode = 0; mode < 2; mode += 1) {
    assert.ok(
      contrast(backgrounds[mode], foregrounds[mode]) >= 4.5,
      `${palette} mode ${mode} contrast must be at least 4.5:1`,
    );
  }
}

console.log("HTML renderer conformance: PASS");
console.log("  i18n/event guides/swap motion/update dependencies/custom events: PASS");
console.log("  roles and red-black node colors light/dark contrast >= 4.5:1: PASS");
console.log("  standalone/CSP/reduced-motion/FLIP/grid/graph hooks: PASS");
