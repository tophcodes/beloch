// The primary navigation. The header, the mobile drawer and the landing
// footer all read this list, so a link is added in one place.
export const NAV_LINKS = [
  { label: "Playground", href: "/playground/" },
  { label: "Docs", href: "/language/" },
] as const;

// The repository stands in the footer only.
export const REPO_LINK = { label: "GitHub", href: "https://github.com/tophcodes/beloch" } as const;
