// Browser verification: drives the live Astro dev server with puppeteer-core
// (pointed at a nix-fetched Chromium) to confirm the playground's default
// rabbit-ear program folds to an <svg> via the FLINT-wasm qqbar backend,
// instead of showing the old "braucht native Auswertung" notice.
//
// Usage: node spike/verify-playground.mjs <baseUrl>
import puppeteer from "puppeteer-core";
import { writeFile } from "node:fs/promises";

const baseUrl = process.argv[2] ?? "http://localhost:4321";
const chromiumPath = process.env.CHROMIUM_PATH;
if (!chromiumPath) {
  console.error("CHROMIUM_PATH env var not set");
  process.exit(1);
}

const consoleMessages = [];
const pageErrors = [];

async function waitForResult(page, timeoutMs = 20000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const state = await page.evaluate(() => {
      const result = document.querySelector(".pg-result");
      if (!result) return { found: false };
      const svg = result.querySelector("svg");
      const errNotice = result.querySelector(".pg-notice-error");
      const infoNotice = result.querySelector(".pg-notice-info");
      return {
        found: true,
        hasSvg: !!svg,
        errorText: errNotice ? errNotice.textContent : null,
        infoText: infoNotice ? infoNotice.textContent : null,
        innerHTMLSnippet: result.innerHTML.slice(0, 300),
      };
    });
    if (state.hasSvg) return state;
    if (state.errorText) return state;
    // "wertet aus …" is the in-flight info notice; anything else info-ish
    // that isn't the initial prompt or the in-flight spinner, treat as settled.
    if (
      state.infoText &&
      !state.infoText.includes("wertet aus") &&
      !state.infoText.includes("Run")
    ) {
      return state;
    }
    await new Promise((r) => setTimeout(r, 300));
  }
  return { timedOut: true };
}

async function main() {
  const puppeteerExtra = await import("puppeteer-core");
  const browser = await puppeteerExtra.launch({
    executablePath: chromiumPath,
    headless: true,
    args: ["--no-sandbox", "--disable-setuid-sandbox"],
  });
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1400, height: 900 });

    page.on("console", (msg) => {
      consoleMessages.push(`[${msg.type()}] ${msg.text()}`);
    });
    page.on("pageerror", (err) => {
      pageErrors.push(String(err));
    });

    const url = `${baseUrl}/playground/`;
    console.log(`Navigating to ${url}`);
    await page.goto(url, { waitUntil: "networkidle0", timeout: 30000 });

    console.log("Waiting for default rabbit-ear program to auto-run...");
    const state1 = await waitForResult(page, 20000);
    console.log("RESULT (default program):", JSON.stringify(state1, null, 2));

    await page.screenshot({
      path: "playground-browser.png",
      fullPage: false,
    });
    console.log("Screenshot saved: spike/playground-browser.png");

    // Second program: known-good single-ear rabbit-ear fold (incenter,
    // toward .a), from tests/cases/collapse/flatten-rabbit-ear-toward-a.bel —
    // the default playground demo predates the (staying) clause convention
    // and errors on this branch, so this is the real end-to-end √2 exercise.
    const secondProgram = [
      "paper square",
      "",
      "mark --diag = through .a .c",
      "mark --ea = map --ab onto --diag",
      "mark --eb = map --ab onto --bc",
      "mark --ec = map --bc onto --diag",
      "",
      "--ear = flatten (--ea & .a) (--ec & .c) (--eb & .b) {toward .a}",
      ".t = --ear * --ab",
    ].join("\n");
    console.log("Typing second program and clicking Run...");
    await page.evaluate(() => {
      const ta = document.querySelector(".pg-source");
      ta.value = "";
    });
    const textarea = await page.$(".pg-source");
    await textarea.click({ clickCount: 3 });
    await textarea.press("Backspace");
    await textarea.type(secondProgram, { delay: 5 });
    await page.click(".pg-run");

    const state2 = await waitForResult(page, 20000);
    console.log("RESULT (single-ear program):", JSON.stringify(state2, null, 2));

    await page.screenshot({
      path: "playground-singleear.png",
      fullPage: false,
    });
    console.log("Screenshot saved: spike/playground-singleear.png");

    await writeFile(
      "verify-playground-console.log",
      consoleMessages.join("\n") + "\n\n--- pageerrors ---\n" + pageErrors.join("\n"),
    );

    console.log("\n--- console messages ---");
    for (const m of consoleMessages) console.log(m);
    console.log("--- pageerrors ---");
    for (const e of pageErrors) console.log(e);

    const success1 = state1.hasSvg === true;
    const success2 = state2.hasSvg === true;
    console.log(`\nSUCCESS default program svg: ${success1}`);
    console.log(`SUCCESS single-ear program svg: ${success2}`);

    if (!success1) {
      console.error("FAIL: default program did not render an svg");
      process.exitCode = 1;
    }
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error("verify-playground.mjs crashed:", err);
  process.exit(1);
});
