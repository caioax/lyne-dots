pragma ComponentBehavior: Bound
import QtQuick
import qs.services

// The dashboard's GIF (Capoo unless another was picked in Settings),
// moving only while something plays
AnimatedImage {
    // Hidden while paused, instead of standing still
    property bool onlyWhilePlaying: false

    visible: DashboardService.showGif && MprisService.hasPlayer && (!onlyWhilePlaying || MprisService.isPlaying)
    source: DashboardService.showGif ? DashboardService.gifSource : ""
    playing: visible && MprisService.isPlaying
    fillMode: AnimatedImage.PreserveAspectFit
    asynchronous: true
}
