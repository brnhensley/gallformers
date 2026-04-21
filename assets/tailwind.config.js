const plugin = require("tailwindcss/plugin")

module.exports = {
  content: [
    "./js/**/*.js",
    "./css/**/*.css",
    "../lib/gallformers_web/**/*.*ex"
  ],
  safelist: [
    { pattern: /^(gf|ph)-/ }
  ],
  theme: {
    extend: {
      colors: {
        "gf-sky-blue": "#c1e0f3",
        "gf-autumn": "#bc6428",
        "gf-maroon": "#661419",
        "gf-blue": "#228be6",
        "gf-cream": "#fefce8",
        "cadet-blue": "#96adc8",
        canary: "#fef9c3",
        independence: "#585563",
        "new-york-pink": "#ce796b",
        "persian-orange": "#c18c5d",
        "table-header": "#96adc8",
        "table-selected": "#fef9c3"
      },
      fontFamily: {
        sans: [
          "League Spartan",
          "-apple-system",
          "BlinkMacSystemFont",
          '"Segoe UI"',
          "Roboto",
          "Oxygen",
          "Ubuntu",
          "sans-serif"
        ]
      }
    }
  },
  plugins: [
    require("./vendor/icons"),
    require("@tailwindcss/typography"),
    plugin(function({ addVariant }) {
      addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])
      addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])
      addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"])
    })
  ]
}
