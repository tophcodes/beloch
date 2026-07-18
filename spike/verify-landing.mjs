// Browser verification for the landing page at `/`: confirms the hero shows
// a build-time static SVG instantly, that the live worker boots + renders on
// first gesture, that example chips load + run a sample, and that the
// /playground/ -> / redirect and /introduction/ route both work.
//
// Usage: node spike/verify-landing.mjs <baseUrl>
import { writeFile } from "node:fs/promises";

const baseUrl = process.argv[2] ?? "http://localhost:4321";
const chromiumPath = process.env.CHROMIUM_PATH;
if (!chromiumPath) {
  console.error("CHROMIUM_PATH env var not set");
  process.exit(1);
}

const consoleMessages = [];
const pageErrors = [];

async function waitForSvg(page, timeoutMs = 15000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const state = await page.evaluate(() => {
      const result = document.querySelector(".pg-result");
      if (!result) return { found: false };
      const svg = result.querySelector("svg");
      const errNotice = result.querySelector(".pg-notice-error");
      return { found: true, hasSvg: !!svg, errorText: errNotice ? errNotice.textContent : null };
    });
    if (state.hasSvg || state.errorText) return state;
    await new Promise((r) => setTimeout(r, 300));
  }
  return { timedOut: true };
}

async function main() {
  const puppeteer = await import("puppeteer-core");
  const browser = await puppeteer.launch({
    executablePath: chromiumPath,
    headless: true,
    args: ["--no-sandbox", "--disable-setuid-sandbox"],
  });
  let failed = false;
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1400, height: 1000 });
    page.on("console", (msg) => consoleMessages.push(`[${msg.type()}] ${msg.text()}`));
    page.on("pageerror", (err) => pageErrors.push(String(err)));

    console.log(`\n=== 1. Load / — assert instant static SVG (pre-interaction) ===`);
    await page.goto(`${baseUrl}/`, { waitUntil: "networkidle0", timeout: 30000 });
    const seedState = await page.evaluate(() => {
      const result = document.querySelector(".pg-result");
      return { hasSvg: !!result?.querySelector("svg") };
    });
    console.log("Seed state:", JSON.stringify(seedState));
    if (!seedState.hasSvg) {
      console.error("FAIL: hero .pg-result has no <svg> before any interaction");
      failed = true;
    } else {
      console.log("PASS: hero shows a static SVG instantly");
    }

    console.log(`\n=== 2. Focus + type in .pg-source — assert live worker boots + renders ===`);
    await page.click(".pg-source");
    await page.keyboard.type(" ", { delay: 10 });
    const liveState = await waitForSvg(page, 15000);
    console.log("Live state:", JSON.stringify(liveState));
    if (!liveState.hasSvg) {
      console.error("FAIL: live worker did not render an <svg> after gesture");
      failed = true;
    } else {
      console.log("PASS: live worker booted and rendered a fold");
    }
    console.log("Console messages so far:", consoleMessages.length);
    console.log("Page errors so far:", pageErrors.length);
    for (const m of consoleMessages) console.log(m);
    for (const e of pageErrors) console.log("pageerror:", e);
    const badConsole = [...consoleMessages, ...pageErrors].some((m) =>
      /wasm|QqbarWasm|ml_qqbar|error/i.test(m) && !/\[log\]|\[info\]/.test(m),
    );
    if (pageErrors.length > 0) {
      console.error("FAIL: page errors present");
      failed = true;
    }

    console.log(`\n=== 3. Click an example chip — assert source changes + re-render ===`);
    const beforeSrc = await page.$eval(".pg-source", (el) => el.value);
    await page.evaluate(() => {
      const chips = document.querySelectorAll(".example-chip");
      const fish = Array.from(chips).find((c) => c.textContent?.includes("Fish"));
      fish?.click();
    });
    await new Promise((r) => setTimeout(r, 500));
    const afterSrc = await page.$eval(".pg-source", (el) => el.value);
    console.log("Source changed:", beforeSrc !== afterSrc);
    if (beforeSrc === afterSrc) {
      console.error("FAIL: example chip did not change the editor source");
      failed = true;
    }
    const chipState = await waitForSvg(page, 15000);
    console.log("Chip run state:", JSON.stringify(chipState));
    if (!chipState.hasSvg) {
      console.error("FAIL: example chip click did not render an <svg>");
      failed = true;
    } else {
      console.log("PASS: example chip loaded + rendered a sample");
    }

    await page.screenshot({ path: "spike/landing.png", fullPage: true });
    console.log("\nScreenshot saved: spike/landing.png");

    console.log(`\n=== 4. Load /playground/ — assert redirect to / ===`);
    await page.goto(`${baseUrl}/playground/`, { waitUntil: "networkidle0", timeout: 30000 });
    const url1 = page.url();
    console.log("Landed at:", url1);
    if (!/\/$/.test(new URL(url1).pathname) || new URL(url1).pathname !== "/") {
      console.error("FAIL: /playground/ did not redirect to /");
      failed = true;
    } else {
      console.log("PASS: /playground/ redirects to /");
    }

    console.log(`\n=== 5. Load /introduction/ — assert old docs home renders ===`);
    await page.goto(`${baseUrl}/introduction/`, { waitUntil: "networkidle0", timeout: 30000 });
    const introText = await page.evaluate(() => document.body.textContent ?? "");
    const hasIntro = introText.includes("Beloch is a declarative language for origami");
    console.log("Has introduction content:", hasIntro);
    if (!hasIntro) {
      console.error("FAIL: /introduction/ does not render the old docs home content");
      failed = true;
    } else {
      console.log("PASS: /introduction/ renders");
    }

    await writeFile(
      "spike/verify-landing-console.log",
      consoleMessages.join("\n") + "\n\n--- pageerrors ---\n" + pageErrors.join("\n"),
    );

    console.log(`\n=== SUMMARY: ${failed ? "FAIL" : "PASS"} ===`);
    if (failed) process.exitCode = 1;
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error("verify-landing.mjs crashed:", err);
  process.exit(1);
});
