"use strict";

const fs = require("node:fs");
const path = require("node:path");

(async () => {
  const {getUserAgentRegex} = await import("browserslist-useragent-regexp");

  const rootDir = path.resolve(__dirname, "..", "..");
  const outputPath = path.join(rootDir, "priv", "browser_support_regex.json");

  const regex = getUserAgentRegex({
    path: rootDir,
    allowHigherVersions: true
  });

  fs.mkdirSync(path.dirname(outputPath), {recursive: true});
  fs.writeFileSync(
    outputPath,
    JSON.stringify(
      {
        source: regex.source,
        flags: regex.flags
      },
      null,
      2
    ) + "\n"
  );
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
