// Catches the links clicked in WhatsApp Web before Chromium opens a window
// for them (it would flash before background.js closes it): left and
// middle clicks on external links, and window.open calls relayed by main.js.

const HOME = "web.whatsapp.com";

function external(url) {
    try {
        const u = new URL(url, location.href);
        return (u.protocol === "https:" || u.protocol === "http:") && u.hostname !== HOME;
    } catch (e) {
        return false;
    }
}

function onClick(event) {
    if (event.button > 1)
        return;
    const link = event.target instanceof Element ? event.target.closest("a[href]") : null;
    if (!link || !external(link.href))
        return;
    event.preventDefault();
    event.stopImmediatePropagation();
    chrome.runtime.sendMessage({ url: link.href });
}

document.addEventListener("click", onClick, true);
document.addEventListener("auxclick", onClick, true);

window.addEventListener("message", event => {
    if (event.source === window && typeof event.data?.lyneOpenLink === "string" && external(event.data.lyneOpenLink))
        chrome.runtime.sendMessage({ url: event.data.lyneOpenLink });
});
