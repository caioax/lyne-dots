pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import "../rows/"

// Bar template (bar.style) with drawn previews: Settings › Bar and the
// welcome screen
TemplatePicker {
    label: I18n.tr("Template")
    description: I18n.tr("How the bar sits on the screen")
    path: "bar.style"
    options: [
        {
            label: I18n.tr("Docked"),
            value: "docked"
        },
        {
            label: I18n.tr("Docked corners"),
            value: "docked-corners"
        },
        {
            label: I18n.tr("Floating"),
            value: "floating"
        },
        {
            label: I18n.tr("Islands"),
            value: "islands"
        }
    ]
    preview: Component {
        BarStylePreview {}
    }
}
