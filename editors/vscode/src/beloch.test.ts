import { test, expect } from "bun:test";
import { resolveBelochArgv } from "./beloch";

test("prefers the configured path", () => {
  const argv = resolveBelochArgv({ configPath: "/opt/beloch", existsOnPath: () => true });
  expect(argv).toEqual(["/opt/beloch"]);
});

test("falls back to PATH when no config", () => {
  const argv = resolveBelochArgv({ configPath: undefined, existsOnPath: (c) => c === "beloch" });
  expect(argv).toEqual(["beloch"]);
});

test("falls back to dune exec when not on PATH", () => {
  const argv = resolveBelochArgv({ configPath: undefined, existsOnPath: () => false });
  expect(argv).toEqual(["dune", "exec", "beloch", "--"]);
});

test("ignores an empty config path", () => {
  const argv = resolveBelochArgv({ configPath: "", existsOnPath: () => false });
  expect(argv).toEqual(["dune", "exec", "beloch", "--"]);
});
