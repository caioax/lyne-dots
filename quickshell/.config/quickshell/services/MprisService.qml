pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    // --- PLAYER LIST ---
    readonly property list<MprisPlayer> players: Mpris.players.values
    property MprisPlayer activePlayer: null
    readonly property bool hasPlayer: activePlayer !== null
    property list<MprisPlayer> orderedPlayers

    // --- TRACK METADATA ---
    readonly property string title: activePlayer?.trackTitle ?? "Unknown"
    readonly property string artist: activePlayer?.trackArtist ?? "Unknown"
    readonly property string artUrl: activePlayer?.trackArtUrl ?? ""
    readonly property string album: activePlayer?.trackAlbum ?? ""
    readonly property string identity: activePlayer?.identity ?? ""

    // --- PLAYBACK STATE ---
    readonly property bool isPlaying: activePlayer?.isPlaying ?? false
    readonly property bool anyPlaying: players.some(p => p.isPlaying)

    // --- POSITION ---
    readonly property real position: activePlayer?.position ?? 0
    readonly property real length: activePlayer?.length ?? 0
    readonly property bool positionSupported: activePlayer?.positionSupported ?? false
    readonly property bool canSeek: activePlayer?.canSeek ?? false

    // --- CAPABILITIES ---
    readonly property bool canNext: activePlayer?.canGoNext ?? false
    readonly property bool canPrevious: activePlayer?.canGoPrevious ?? false
    readonly property bool canToggle: activePlayer?.canTogglePlaying ?? false

    // --- LOOP & SHUFFLE ---
    readonly property var loopState: activePlayer?.loopState ?? MprisLoopState.None
    readonly property bool loopSupported: activePlayer?.loopSupported ?? false
    readonly property bool shuffle: activePlayer?.shuffle ?? false
    readonly property bool shuffleSupported: activePlayer?.shuffleSupported ?? false

    // --- VOLUME ---
    // 0-1. Some players (Harmonoid) report it in percent instead, though they
    // still take 0-1 when it's set: remembered per player once seen above 2
    // (the spec allows a little over 1 for boost)
    readonly property real volume: rawVolume / volumeScale
    readonly property real rawVolume: activePlayer?.volume ?? 0
    readonly property real volumeScale: rawVolume > 2 || percentVolume[activePlayer?.dbusName ?? ""] ? 100 : 1
    property var percentVolume: ({})
    onRawVolumeChanged: {
        if (rawVolume > 2 && activePlayer)
            percentVolume[activePlayer.dbusName] = true;
    }
    readonly property bool volumeSupported: activePlayer?.volumeSupported ?? false

    // --- POSITION TRACKING ---
    readonly property int positionInterval: 500

    Timer {
        running: root.hasPlayer && root.isPlaying && root.positionSupported
        interval: root.positionInterval
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.activePlayer && Mpris.players.values.includes(root.activePlayer))
                root.activePlayer.positionChanged();
        }
    }

    // --- TRIGGERS ---
    Connections {
        target: Mpris.players
        function onValuesChanged() {
            root.updateActivePlayer();
        }
    }

    // --- MONITORING ---
    Instantiator {
        model: Mpris.players.values

        delegate: QtObject {
            required property MprisPlayer modelData
            property bool isPlaying: modelData.isPlaying ?? false
            // The player that starts playing takes over
            onIsPlayingChanged: {
                if (isPlaying)
                    root.activePlayer = modelData;
                root.updateActivePlayer();
            }
        }

        onObjectAdded: root.updateActivePlayer()
        onObjectRemoved: root.updateActivePlayer()
    }

    // --- DECISION LOGIC ---
    // The active player stays until another one starts playing or the user
    // picks one (selectPlayer); when it goes away, a playing one (or the
    // first) takes its place
    function updateActivePlayer() {
        const rawList = Mpris.players.values;

        if (rawList.length === 0) {
            root.activePlayer = null;
            root.orderedPlayers = [];
            return;
        }

        if (!root.activePlayer || !rawList.includes(root.activePlayer))
            root.activePlayer = rawList.find(p => p.isPlaying) ?? rawList[0];

        // Update ordered list (active first)
        const others = rawList.filter(p => p !== root.activePlayer);
        root.orderedPlayers = [root.activePlayer].concat(others);
    }

    function selectPlayer(player: MprisPlayer) {
        if (!player || player === activePlayer)
            return;
        activePlayer = player;
        updateActivePlayer();
    }

    // Icon of the player's app (from its desktop entry), "" when unknown
    function playerIcon(player: MprisPlayer): string {
        if (!player)
            return "";
        // Some players (Harmonoid) give a path instead of the entry's id
        const id = (player.desktopEntry || player.identity).split("/").pop().replace(/\.desktop$/, "");
        const entry = DesktopEntries.heuristicLookup(id);
        return entry?.icon ? Quickshell.iconPath(entry.icon, true) : "";
    }

    // --- CONTROLS ---
    function playPause() {
        if (activePlayer?.canTogglePlaying)
            activePlayer.togglePlaying();
    }

    function next() {
        if (activePlayer?.canGoNext)
            activePlayer.next();
    }

    function previous() {
        if (activePlayer?.canGoPrevious)
            activePlayer.previous();
    }

    function setPosition(pos: real) {
        if (activePlayer?.canSeek)
            activePlayer.position = pos;
    }

    function restart() {
        if (activePlayer?.canSeek)
            activePlayer.position = 0;
    }

    function cycleLoop() {
        if (!activePlayer?.loopSupported)
            return;

        if (activePlayer.loopState === MprisLoopState.None)
            activePlayer.loopState = MprisLoopState.Track;
        else if (activePlayer.loopState === MprisLoopState.Track)
            activePlayer.loopState = MprisLoopState.Playlist;
        else
            activePlayer.loopState = MprisLoopState.None;
    }

    function toggleShuffle() {
        if (activePlayer?.shuffleSupported)
            activePlayer.shuffle = !activePlayer.shuffle;
    }

    function setVolume(vol: real) {
        if (activePlayer)
            activePlayer.volume = Math.max(0, Math.min(1, vol));
    }
}
