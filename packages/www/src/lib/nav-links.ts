// The primary navigation. The header, the mobile drawer and the landing
// footer all read this list, so a link is added in one place.
export const NAV_LINKS = [
  { label: "Guide", href: "/guide/first-folds/" },
  { label: "Reference", href: "/language/" },
  { label: "Playground", href: "/playground/" },
] as const;

// The repository, at the end of the header and in the footer.
export const REPO_LINK = { label: "GitHub", href: "https://github.com/tophcodes/beloch" } as const;
