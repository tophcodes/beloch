import { test, expect } from "bun:test";
import { PACKAGE } from "@beloch/scene";

test("workspace resolves package by name", () => {
  expect(PACKAGE).toBe("@beloch/scene");
});
