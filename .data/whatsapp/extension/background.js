// Links clicked in WhatsApp Web go to the default browser (the
// lyne.open_link native host runs xdg-open). content.js catches them before
// Chromium opens anything; a new tab that still shows up with a page outside
// WhatsApp is handed off and closed. Installed by `lyne whatsapp`.

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

// From content.js; without the host the link opens in a Chromium tab
chrome.runtime.onMessage.addListener((message, sender) => {
    if (sender.id !== chrome.runtime.id || !sender.url?.startsWith("https://" + HOME + "/") || !external(message?.url))
        return;
    chrome.runtime.sendNativeMessage("lyne.open_link", { url: message.url }, reply => {
        if (chrome.runtime.lastError || !reply?.ok)
            chrome.tabs.create({ url: message.url });
    });
});

chrome.tabs.onCreated.addListener(tab => handOff(tab.id, tab.pendingUrl || tab.url || ""));
chrome.tabs.onUpdated.addListener((tabId, change) => {
    if (change.url)
        handOff(tabId, change.url);
});
chrome.tabs.onRemoved.addListener(tabId => handled.delete(tabId));
