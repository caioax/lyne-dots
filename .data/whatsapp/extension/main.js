// Runs in the page: window.open of an external page goes to content.js
// (the default browser) instead of a Chromium window.

(() => {
    const open = window.open;
    window.open = function (url, ...rest) {
        try {
            const u = new URL(url, location.href);
            if ((u.protocol === "https:" || u.protocol === "http:") && u.hostname !== location.hostname) {
                window.postMessage({ lyneOpenLink: u.href }, location.origin);
                return null;
            }
        } catch (e) {}
        return open.call(this, url, ...rest);
    };
})();
