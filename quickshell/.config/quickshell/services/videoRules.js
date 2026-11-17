.pragma library

// When a video wallpaper pauses (WallpaperService, through mpv's IPC). One
// mpvpaper plays on every screen, so a fullscreen window pauses it only once
// every screen is covered: a free screen keeps the video moving.
//
//   rules   { covered, locked, battery }: the rules turned on in Settings
//   now     { screens, coveredScreens, locked, onBattery }: screen names,
//           the ones a fullscreen window covers, the session lock, power

function allCovered(screens, coveredScreens) {
    return screens.length > 0 && screens.every(s => coveredScreens.includes(s));
}

// Whether the video should be paused now
function shouldPause(rules, now) {
    if (rules.locked && now.locked)
        return true;
    if (rules.battery && now.onBattery)
        return true;
    return rules.covered === true && allCovered(now.screens, now.coveredScreens);
}
