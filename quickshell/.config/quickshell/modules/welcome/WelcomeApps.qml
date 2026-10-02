pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../settings/pages/"

// Apps step: the default apps, used by the shell, its shortcuts and
// xdg-open (Settings › Apps also changes the shortcuts)
ColumnLayout {
    id: root

    // Called by WelcomeWindow before Escape closes the window
    function handleEscape(): bool {
        return defaults.handleEscape();
    }

    spacing: Config.spacing * 3

    // md-apps
    WelcomeHeader {
        icon: "\u{f003b}"
        title: "Apps"
        description: "The apps the shortcuts, the launcher and links open. Settings › Apps also changes their shortcuts."
    }

    AppDefaultsGroup {
        id: defaults
    }
}
