.pragma library

// Automatic power profiles for PowerProfileService: power saver when the
// battery runs low or the charger is unplugged, and back to the profile from
// before when it's plugged in again. Rules act on changes only (unplugging,
// the level crossing below the limit), never on the state as it is, so a
// profile picked by hand stays until the next change. No rule acts while an
// app holds a profile.
//
//   rules  { lowBattery, level, onUnplug }
//   power  { onBattery, percentage }, before (was) and after (now) a change
//   auto   { reason, previous }: the rule that switched ("lowBattery",
//          "unplugged" or "" for none) and the profile it switched from

const none = {
    reason: "",
    previous: ""
};

// The power source or the battery level changed. Returns { auto, switchTo }
// (switchTo "" = leave the profile as it is)
function powerChanged(rules, was, now, profile, held, auto) {
    // Plugged in: back to the profile from before, unless it was changed
    // since the rule switched
    if (was.onBattery && !now.onBattery)
        return {
            auto: none,
            switchTo: auto.reason !== "" && profile === "power-saver" ? auto.previous : ""
        };

    if (!now.onBattery || held || profile === "power-saver")
        return {
            auto: auto,
            switchTo: ""
        };

    const unplugged = !was.onBattery;
    const low = rules.lowBattery && now.percentage < rules.level && (unplugged || was.percentage >= rules.level);
    const reason = low ? "lowBattery" : unplugged && rules.onUnplug ? "unplugged" : "";
    if (reason === "")
        return {
            auto: auto,
            switchTo: ""
        };
    return {
        auto: {
            reason: reason,
            previous: profile
        },
        switchTo: "power-saver"
    };
}

// The profile changed: one picked by hand (anything but power saver) ends
// the rule, so plugging in won't switch it back
function profileChanged(auto, profile) {
    return auto.reason !== "" && profile !== "power-saver" ? none : auto;
}
