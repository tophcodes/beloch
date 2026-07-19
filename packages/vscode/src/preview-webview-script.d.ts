// Ambient type for the virtual module `esbuild.mjs`'s `webviewScriptPlugin`
// resolves at bundle time — `preview.ts` imports it to get `preview-webview.ts`
// (compiled to plain browser JS) as an inline string. tsc has no real file to
// resolve, so this declares the module directly for type-checking purposes.
declare module "beloch:preview-webview-script" {
  const script: string;
  export default script;
}
