pragma ComponentBehavior: Bound
import QtQuick
import qs.services

// The dashboard's GIF (bongocat unless another was picked in Settings),
// moving only while something plays
AnimatedImage {
    visible: DashboardService.showGif && MprisService.hasPlayer
    source: DashboardService.showGif ? DashboardService.gifSource : ""
    playing: visible && MprisService.isPlaying
    fillMode: AnimatedImage.PreserveAspectFit
    asynchronous: true
}
