import https from "node:https";

const SITE_URL = process.env.SITE_URL;

function checkSite(url) {
  return new Promise((resolve, reject) => {
    https
      .get(url, (res) => {
        res.on("data", () => {});
        res.on("end", () => {
          if (res.statusCode === 200) {
            resolve(res.statusCode);
          } else {
            reject(new Error(`${url} returned status ${res.statusCode}`));
          }
        });
      })
      .on("error", (err) => {
        reject(new Error(`${url} request failed: ${err.message}`));
      });
  });
}

export async function handler() {
  const status = await checkSite(SITE_URL);
  console.log(`Health check passed: ${SITE_URL} returned ${status}`);
  return { status };
}
