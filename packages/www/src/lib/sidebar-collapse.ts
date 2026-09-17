// Sidebar collapse state. The Sidebar component toggles the attribute; this
// head script restores the stored state before first paint so a collapsed
// sidebar does not flash open on navigation.
export const STORAGE_KEY = "beloch:sidebar-collapsed";

export function sidebarCollapseScript(): string {
  return (
    "(function(){try{" +
    "if(localStorage.getItem(" + JSON.stringify(STORAGE_KEY) + ")==='1')" +
    "document.documentElement.setAttribute('data-sidebar-collapsed','');" +
    "}catch(e){}})();"
  );
}
