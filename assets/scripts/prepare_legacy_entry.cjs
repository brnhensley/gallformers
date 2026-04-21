const fs = require("fs")
const path = require("path")

const sourcePath = path.resolve(__dirname, "../css/app.css")
const targetPath = path.resolve(__dirname, "../css/app_legacy.css")

let css = fs.readFileSync(sourcePath, "utf8")

css = css.replace(
  /@import "tailwindcss" source\(none\);\n@source "\.\.\/css";\n@source "\.\.\/js";\n@source "\.\.\/\.\.\/lib\/gallformers_web";\n/,
  "@tailwind base;\n@tailwind components;\n@tailwind utilities;\n"
)

css = css.replace(/^@plugin .*\n/gm, "")
css = css.replace(/^@custom-variant .*\n/gm, "")
css = css.replace(/^@source .*\n/gm, "")
css = css.replace("@theme {", ":root {")

fs.writeFileSync(targetPath, css)
