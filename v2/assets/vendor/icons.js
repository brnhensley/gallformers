/**
 * Unified icon plugin for Gallformers
 *
 * Handles two icon sources:
 * - "gf-*" prefix: Custom gallformers domain icons (gall, host, taxon, source, place)
 * - "ph-*" prefix: Phosphor icons (MIT licensed)
 *
 * Icons are rendered using CSS masks, allowing them to inherit currentColor.
 */
const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

module.exports = plugin(function({matchComponents, theme}) {
  let values = {}

  // Load custom Gallformers icons from priv/static/images/icons
  const gfIconsDir = path.join(__dirname, "../../priv/static/images/icons")
  if (fs.existsSync(gfIconsDir)) {
    fs.readdirSync(gfIconsDir).forEach(file => {
      if (file.endsWith(".svg")) {
        let name = path.basename(file, ".svg")
        values[name] = {name, fullPath: path.join(gfIconsDir, file), prefix: "gf"}
      }
    })
  }

  // Load Phosphor icons from assets/vendor/phosphor (committed to repo)
  const phIconsDir = path.join(__dirname, "phosphor")
  if (fs.existsSync(phIconsDir)) {
    fs.readdirSync(phIconsDir).forEach(file => {
      if (file.endsWith(".svg")) {
        let name = path.basename(file, ".svg")
        values[name] = {name, fullPath: path.join(phIconsDir, file), prefix: "ph"}
      }
    })
  }

  // Register "gf" component for gallformers icons
  matchComponents({
    "gf": ({name, fullPath, prefix}) => {
      if (prefix !== "gf") return {}
      let content = fs.readFileSync(fullPath).toString().replace(/\r?\n|\r/g, "")
      content = encodeURIComponent(content)
      return {
        [`--gf-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
        "-webkit-mask": `var(--gf-${name})`,
        "mask": `var(--gf-${name})`,
        "mask-repeat": "no-repeat",
        "mask-size": "contain",
        "mask-position": "center",
        "background-color": "currentColor",
        "vertical-align": "middle",
        "display": "inline-block",
        "width": theme("spacing.6"),
        "height": theme("spacing.6")
      }
    }
  }, {values: Object.fromEntries(
    Object.entries(values).filter(([_, v]) => v.prefix === "gf")
  )})

  // Register "ph" component for Phosphor icons
  matchComponents({
    "ph": ({name, fullPath, prefix}) => {
      if (prefix !== "ph") return {}
      let content = fs.readFileSync(fullPath).toString().replace(/\r?\n|\r/g, "")
      content = encodeURIComponent(content)
      return {
        [`--ph-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
        "-webkit-mask": `var(--ph-${name})`,
        "mask": `var(--ph-${name})`,
        "mask-repeat": "no-repeat",
        "mask-size": "contain",
        "mask-position": "center",
        "background-color": "currentColor",
        "vertical-align": "middle",
        "display": "inline-block",
        "width": theme("spacing.6"),
        "height": theme("spacing.6")
      }
    }
  }, {values: Object.fromEntries(
    Object.entries(values).filter(([_, v]) => v.prefix === "ph")
  )})
})
