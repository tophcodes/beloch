import { test, expect } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { parseMli, type ApiItem } from "./api-register.ts";

const source = readFileSync(join(import.meta.dir, "fixtures", "api-register-sample.mli"), "utf8");
const items = parseMli(source, "Sample");
const byPath = new Map(items.map((i) => [i.path, i]));

function item(path: string): ApiItem {
	const found = byPath.get(path);
	if (!found) throw new Error(`${path} missing; register has ${[...byPath.keys()].join(", ")}`);
	return found;
}

test("documented types and values are entries, undocumented ones are not", () => {
	expect([...byPath.keys()]).toEqual([
		"Sample.face",
		"Sample.t",
		"Sample.violation",
		"Sample.violation.Bad_index",
		"Sample.violation.Taco_taco",
		"Sample.hinge",
		"Sample.hinge.fa",
		"Sample.hinge.fb",
		"Sample.make",
		"Sample.rank",
	]);
});

test("the signature is the declaration as written, without its comments", () => {
	expect(item("Sample.face").signature).toBe("type face = int array");
	expect(item("Sample.make").signature).toBe(
		"val make : faces:face array -> unit -> (t, violation) result",
	);
	expect(item("Sample.violation").signature).toBe(
		"type violation =\n  | Bad_index of string\n  | Taco_taco of int * int",
	);
	expect(item("Sample.violation.Taco_taco").signature).toBe("| Taco_taco of int * int");
	expect(item("Sample.hinge.fa").signature).toBe("fa : int");
});

test("odoc markup becomes markdown", () => {
	expect(item("Sample.face").doc).toBe("A polygon, given by the indices of `point`s.");
	expect(item("Sample.make").doc).toBe("The only constructor; it rejects `faces` that overlap.");
});

test("@see lines become realizations and leave the prose", () => {
	expect(item("Sample.t").doc).toBe("");
	expect(item("Sample.t").realizes).toEqual([
		{
			url: "https://beloch.toph.so/model/#def-flat-state",
			id: "def-flat-state",
			text: "realizes the flat folded state",
		},
	]);
	expect(item("Sample.violation.Taco_taco").doc).toBe("hinges i and j interleave");
	expect(item("Sample.violation.Taco_taco").realizes[0].id).toBe("cond-taco-taco");
	expect(item("Sample.violation.Bad_index").realizes).toEqual([]);
});

test("constructors and fields hang off their type", () => {
	expect(item("Sample.violation.Taco_taco").parent).toBe("Sample.violation");
	expect(item("Sample.violation.Taco_taco").kind).toBe("constructor");
	expect(item("Sample.hinge.fb").kind).toBe("field");
	expect(item("Sample.hinge").doc).toBe("A crease between two faces.");
});

test("the odoc page and anchor follow the item's kind", () => {
	expect(item("Sample.t").html).toBe("/api/beloch/Beloch/Sample/index.html#type-t");
	expect(item("Sample.make").html).toBe("/api/beloch/Beloch/Sample/index.html#val-make");
	expect(item("Sample.violation.Taco_taco").html).toBe(
		"/api/beloch/Beloch/Sample/index.html#type-violation.Taco_taco",
	);
});

test("a section comment documents no item", () => {
	expect(item("Sample.rank").doc).toBe("The stacking order.");
});
