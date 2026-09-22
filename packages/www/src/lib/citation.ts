/**
 * The project's own citation metadata, read from CITATION.cff at build time.
 *
 * The file is the one place the version, the DOI and the author live, so the
 * footer, the head and the cite page derive from it rather than repeating it:
 * a release bumps one file and the site follows. Only the flat scalars this
 * site shows are read, which is why there is a reader here instead of a YAML
 * dependency (`yaml` is in node_modules transitively, which is not the same as
 * depending on it).
 */
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

/**
 * The author's WebID. It is not read from CITATION.cff because the format has
 * no field for one: `website` means a homepage, and a WebID is the URI that
 * denotes the person and dereferences to a document describing them. Keeping
 * it here rather than bending `website` leaves the CFF file saying what other
 * tools think it says.
 */
export const WEBID = "https://toph.so/profile#me";

export interface Citation {
	title: string;
	version: string;
	dateReleased: string;
	doi: string;
	license: string;
	repository: string;
	url: string;
	familyNames: string;
	givenNames: string;
	orcid: string;
	webid: string;
}

/** `key: "value"` or `key: value`, at the given indent, first match wins. */
function scalar(cff: string, key: string, indent = ""): string {
	const m = cff.match(new RegExp(`^${indent}(?:- )?${key}:[ \\t]*(.*)$`, "m"));
	if (!m) throw new Error(`CITATION.cff has no ${key}`);
	return m[1]!.trim().replace(/^["']|["']$/g, "");
}

function repoRoot(): string {
	if (process.env.BELOCH_REPO_ROOT) return process.env.BELOCH_REPO_ROOT;
	// packages/www/src/lib -> repository root
	return join(fileURLToPath(new URL(".", import.meta.url)), "..", "..", "..", "..");
}

export function readCitation(path = join(repoRoot(), "CITATION.cff")): Citation {
	const cff = readFileSync(path, "utf8");
	return {
		title: scalar(cff, "title"),
		version: scalar(cff, "version"),
		dateReleased: scalar(cff, "date-released"),
		doi: scalar(cff, "doi"),
		license: scalar(cff, "license"),
		repository: scalar(cff, "repository-code"),
		url: scalar(cff, "url"),
		familyNames: scalar(cff, "family-names", "\\s*"),
		givenNames: scalar(cff, "given-names", "\\s*"),
		orcid: scalar(cff, "orcid", "\\s*"),
		webid: WEBID,
	};
}

/** `Mühl, Christopher` — the order a bibliography wants. */
export function citedName(c: Citation): string {
	return `${c.familyNames}, ${c.givenNames}`;
}

/** The DOI as a resolvable link. */
export function doiUrl(c: Citation): string {
	return `https://doi.org/${c.doi}`;
}

export function bibtex(c: Citation): string {
	const year = c.dateReleased.slice(0, 4);
	const key = `${c.familyNames.toLowerCase().normalize("NFD").replace(/[^a-z]/g, "")}${year}beloch`;
	return [
		`@software{${key},`,
		`  author    = {${c.familyNames}, ${c.givenNames}},`,
		`  title     = {${c.title}},`,
		`  year      = {${year}},`,
		`  version   = {${c.version}},`,
		`  doi       = {${c.doi}},`,
		`  url       = {${c.url}},`,
		`  license   = {${c.license}}`,
		`}`,
	].join("\n");
}

/** APA 7, the style a software entry takes there. */
export function apa(c: Citation): string {
	const year = c.dateReleased.slice(0, 4);
	const initials = c.givenNames
		.split(/\s+/)
		.map((n) => `${n[0]}.`)
		.join(" ");
	return `${c.familyNames}, ${initials} (${year}). ${c.title} (Version ${c.version}) [Computer software]. https://doi.org/${c.doi}`;
}
