import { test, expect } from "bun:test";
import { runUi, RUNTIME_SIZE, type RunState } from "./playground-run-state";

const state = (over: Partial<RunState> = {}): RunState => ({
  phase: "cold",
  running: false,
  loadStalled: false,
  ...over,
});

test("Run is available at rest before the runtime has ever loaded", () => {
  const ui = runUi(state());
  expect(ui.disabled).toBe(false);
  expect(ui.title).toBe("Run");
  expect(ui.status).toBe("");
});

test("Run stays available at rest with the runtime ready and the code unchanged", () => {
  const ui = runUi(state({ phase: "ready" }));
  expect(ui.disabled).toBe(false);
  expect(ui.title).toBe("Run");
});

test("a run that changed nothing says nothing", () => {
  const ui = runUi(state({ phase: "ready" }));
  expect(ui.disabled).toBe(false);
  expect(ui.status).toBe("");
});

test("waiting for the runtime names the download size", () => {
  const ui = runUi(state({ phase: "cold", running: true }));
  expect(ui.disabled).toBe(true);
  expect(ui.status).toContain(RUNTIME_SIZE);
});

test("a booting runtime reports loading, not computing", () => {
  expect(runUi(state({ phase: "loading", running: true })).status).toBe(
    `loading runtime (${RUNTIME_SIZE}) …`,
  );
});

test("evaluating on a ready runtime reports computing", () => {
  const ui = runUi(state({ phase: "ready", running: true }));
  expect(ui.disabled).toBe(true);
  expect(ui.status).toBe("computing geometry …");
});

test("a stalled load re-enables Run and says the runtime is still loading", () => {
  const ui = runUi(state({ phase: "loading", loadStalled: true }));
  expect(ui.disabled).toBe(false);
  expect(ui.title).toBe("Run");
  expect(ui.status).toBe("runtime still loading; press Run to retry");
});

test("Run is disabled only while a run is in flight", () => {
  const phases = ["cold", "loading", "ready"] as const;
  for (const phase of phases) {
    expect(runUi(state({ phase })).disabled).toBe(false);
    expect(runUi(state({ phase, running: true })).disabled).toBe(true);
  }
});

test("a measured load reports the share of the runtime that has arrived", () => {
  const ui = runUi(state({ phase: "loading", running: true, progress: 0.42 }));
  expect(ui.status).toBe(`loading runtime · 42 % of ${RUNTIME_SIZE}`);
});

test("an unmeasured load falls back to naming the size alone", () => {
  expect(runUi(state({ phase: "loading", running: true, progress: null })).status).toBe(
    `loading runtime (${RUNTIME_SIZE}) …`,
  );
});

test("a share outside 0 to 1 is clamped rather than printed", () => {
  expect(runUi(state({ phase: "loading", running: true, progress: 1.4 })).status).toContain("100 %");
  expect(runUi(state({ phase: "loading", running: true, progress: -0.2 })).status).toContain("0 %");
});
