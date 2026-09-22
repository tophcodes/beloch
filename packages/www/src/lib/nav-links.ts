// The primary navigation. The landing shell, the docs header and the mobile
// drawer all read this list, so a link is added in one place. A link with an
// `icon` is drawn as that icon and takes its label as the accessible name.
export const NAV_LINKS = [
  { label: "Playground", href: "/playground/" },
  { label: "Docs", href: "/language/" },
  { label: "GitHub", href: "https://github.com/tophcodes/beloch", icon: "github" },
] as const;
