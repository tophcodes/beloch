import * as esbuild from "esbuild";

const watch = process.argv.includes("--watch");

// The specifier `preview.ts` imports to pull in the webview script text; kept
// out of the ordinary module graph via an ambient `declare module` there.
const WEBVIEW_SCRIPT_SPECIFIER = "beloch:preview-webview-script";

/** Bundles `src/preview-webview.ts` (which runs in the webview's browser
 * context) down to a single plain-JS string, so `preview.ts` can inline it
 * into the panel's HTML `<script>` tag instead of shipping/reading a second
 * file at runtime. Re-run on every (re)build so `--watch` picks up edits. */
async function bundleWebviewScript() {
  const result = await esbuild.build({
    entryPoints: ["src/preview-webview.ts"],
    bundle: true,
    format: "iife",
    platform: "browser",
    target: "es2020",
    write: false,
    metafile: true,
  });
  return { text: result.outputFiles[0].text, watchFiles: Object.keys(result.metafile.inputs) };
}

function webviewScriptPlugin() {
  return {
    name: "webview-script",
    setup(build) {
      build.onResolve({ filter: new RegExp(`^${WEBVIEW_SCRIPT_SPECIFIER}$`) }, (args) => ({
        path: args.path,
        namespace: "webview-script-ns",
      }));
      build.onLoad({ filter: /.*/, namespace: "webview-script-ns" }, async () => {
        const { text, watchFiles } = await bundleWebviewScript();
        return {
          contents: `Object.defineProperty(exports, "__esModule", { value: true });\nexports.default = ${JSON.stringify(text)};\n`,
          loader: "js",
          watchFiles,
        };
      });
    },
  };
}

const ctx = await esbuild.context({
  entryPoints: ["src/extension.ts"],
  bundle: true,
  format: "cjs",
  platform: "node",
  target: "node18",
  outfile: "dist/extension.js",
  external: ["vscode"],
  sourcemap: true,
  logLevel: "info",
  plugins: [webviewScriptPlugin()],
});

if (watch) {
  await ctx.watch();
} else {
  await ctx.rebuild();
  await ctx.dispose();
}
