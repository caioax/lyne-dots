// Links clicked in WhatsApp Web open a new Chromium tab: hand any page
// outside WhatsApp to the default browser (the lyne.open_link native host
// runs xdg-open) and close the tab. Installed by `lyne whatsapp`.

const HOME = "web.whatsapp.com";
const handled = new Set();

function external(url) {
    try {
        const u = new URL(url);
        return (u.protocol === "https:" || u.protocol === "http:") && u.hostname !== HOME;
    } catch (e) {
        return false;
    }
}

async function handOff(tabId, url) {
    if (!external(url) || handled.has(tabId))
        return;
    // Only the new browser tabs: never the WhatsApp app window itself
    const tab = await chrome.tabs.get(tabId).catch(() => null);
    const win = tab ? await chrome.windows.get(tab.windowId).catch(() => null) : null;
    if (win?.type !== "normal" || handled.has(tabId))
        return;
    handled.add(tabId);
    chrome.runtime.sendNativeMessage("lyne.open_link", { url }, reply => {
        // Without the host the link stays open here
        if (chrome.runtime.lastError || !reply?.ok) {
            handled.delete(tabId);
            return;
        }
        chrome.tabs.remove(tabId).catch(() => {});
    });
}

chrome.tabs.onCreated.addListener(tab => handOff(tab.id, tab.pendingUrl || tab.url || ""));
chrome.tabs.onUpdated.addListener((tabId, change) => {
    if (change.url)
        handOff(tabId, change.url);
});
chrome.tabs.onRemoved.addListener(tabId => handled.delete(tabId));
