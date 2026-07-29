// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

import {
  "moonbitlang/x@0.4.45",
}

name = "shop1111/frontierlab"

version = "0.7.0"

readme = "README.md"

repository = "https://github.com/shop1111/FrontierLab.git"

license = "MIT"

keywords = [ "algorithm", "trace", "visualization", "education", "svg", "html" ]

description = "A MoonBit algorithm trace protocol and offline HTML/SVG visualization kit."

options(
  exclude: [ "consumer/frontierlab_consumer_demo", "PROJECT_APPLICATION.md" ],
)
