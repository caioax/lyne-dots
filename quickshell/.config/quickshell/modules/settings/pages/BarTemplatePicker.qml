pragma ComponentBehavior: Bound
import QtQuick
import "../rows/"

// Bar template (bar.style) with drawn previews: Settings › Bar and the
// welcome screen
TemplatePicker {
    label: "Template"
    description: "How the bar sits on the screen"
    path: "bar.style"
    options: [
        {
            label: "Docked",
            value: "docked"
        },
        {
            label: "Docked corners",
            value: "docked-corners"
        },
        {
            label: "Floating",
            value: "floating"
        },
        {
            label: "Islands",
            value: "islands"
        }
    ]
    preview: Component {
        BarStylePreview {}
    }
}
