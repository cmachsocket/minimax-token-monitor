import QtQuick
import QtQuick.Layouts as QtLayouts
import QtQuick.Controls as QtControls
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid
pragma ComponentBehavior: Bound   // 静态作用域解析
PlasmoidItem {
    id: root
    readonly property string config_apiKey: Plasmoid.configuration.apiKey || ""
    readonly property int config_refreshInterval: Plasmoid.configuration.refreshInterval || 60

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: compactRepresentation

    // Percent of quota already consumed (0 = nothing used, 100 = exhausted).
    // Source: API field `current_interval_remaining_percent` is inverted here so
    // the property always matches what the UI shows ("usage : X%").
    property int usagePercent: 0

    // "Resets in 2h41m @ 00:00" — formatted from API `remains_time` + `end_time`.
    // Populated only after the first successful fetch; "—" before that.
    property string nextResetLabel: "—"

    property string lastUpdated: "N/A"
    property string errorMessage: ""
    property bool isLoading: false

    // Colors
    readonly property string barColor: "#00D1B2"
    readonly property string bgColor: "#2D2D44"
    readonly property string textColor: "#FFFFFF"
    readonly property string subtextColor: "#A0A0A0"

    compactRepresentation: MouseArea {
        property bool wasExpanded
        Accessible.name: Plasmoid.title
        Accessible.role: Accessible.Button
        onClicked: root.expanded = !wasExpanded
        onPressed: wasExpanded = root.expanded
        QtLayouts.RowLayout {
            anchors.fill: parent
            spacing: 0
            QtControls.Label {
                QtLayouts.Layout.alignment: Qt.AlignCenter
                horizontalAlignment: Text.AlignHCenter
                text: root.usagePercent + "%"
                font.pixelSize: 14
                font.bold: true
                color: root.textColor
            }

            Timer {
                interval: root.config_refreshInterval * 1000
                repeat: true
                onTriggered: root.fetchData()
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation{
        contentItem: Item {
            anchors.fill: parent
            QtLayouts.ColumnLayout{
                anchors.fill: parent
                QtControls.Label{

                    QtLayouts.Layout.alignment: Qt.AlignCenter
                    horizontalAlignment: Text.AlignHCenter
                    text : "usage : " + root.usagePercent + "% / 100%"
                }
                QtControls.ProgressBar{
                    id : progress
                    QtLayouts.Layout.alignment: Qt.AlignCenter
                    implicitHeight: 20
                    padding: 0
                    from: 0
                    to: 100
                    value: root.usagePercent          // green = used, grows with consumption
                    background: Rectangle {
                        implicitHeight: 20
                        color: root.bgColor
                        radius: 3
                    }

                    contentItem: Item {
                        implicitHeight: 20
                        clip: true

                        Rectangle {
                            width: progress.visualPosition * parent.width
                            height: parent.height
                            color: root.barColor
                            radius: 3
                        }
                    }
                }
                QtControls.Label {
                    QtLayouts.Layout.alignment: Qt.AlignCenter
                    font.pixelSize: 12
                    color: root.subtextColor
                    text: "Resets in " + root.nextResetLabel
                }
                QtControls.Button {

                    QtLayouts.Layout.alignment: Qt.AlignCenter
                    flat: true
                    focusPolicy: Qt.NoFocus
                    text : "refresh"
                    icon.source: Qt.resolvedUrl("../icon/refresh.svg")
                    font.pixelSize: 14
                    onClicked: fetchData()
                }
            }
        }
    }

    Component.onCompleted: fetchData()

    // milliseconds → "XhYm" / "Xm" (or "—" for invalid input).
    // API uses ms since epoch for `end_time`/`weekly_end_time` but RELATIVE
    // milliseconds for `remains_time`/`weekly_remains_time`. formatDuration
    // operates on the relative kind (counting down to a near-future moment).
    function formatDuration(ms) {
        if (typeof ms !== "number" || ms < 0) return "—";
        var totalSec = Math.floor(ms / 1000);
        var h = Math.floor(totalSec / 3600);
        var m = Math.floor((totalSec % 3600) / 60);
        if (h > 0) return h + "h" + m + "m";
        return m + "m";
    }

    function fetchData() {
        isLoading = true;
        errorMessage = "";

        if (config_apiKey === "") {
            demoData();
            return;
        }

        var xhr = new XMLHttpRequest();
        xhr.open("GET", "https://www.minimaxi.com/v1/token_plan/remains", true);
        xhr.setRequestHeader("Authorization", "Bearer " + config_apiKey);

        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                let now = new Date();
                lastUpdated = now.toLocaleTimeString(Qt.locale(), "HH:mm");

                if (xhr.status === 200) {
                    try {
                        let resp = JSON.parse(xhr.responseText);
                        if (resp.model_remains) {
                            let usedPct = 0;
                            for (let i = 0; i < resp.model_remains.length; i++) {
                                let m = resp.model_remains[i];
                                // "general" = aggregate LLM token quota
                                // (API no longer exposes MiniMax-M* family names)
                                if (m.model_name === "general") {
                                    let remainingPct = m.current_interval_remaining_percent;
                                    let remaining = (typeof remainingPct === "number") ? remainingPct : 100;
                                    usedPct = 100 - remaining;

                                    // "next reset" combines API `remains_time` (ms until
                                    // reset) with `end_time` (absolute epoch ms → HH:mm).
                                    if (typeof m.remains_time === "number" && typeof m.end_time === "number") {
                                        root.nextResetLabel = formatDuration(m.remains_time)
                                            + " @ " + Qt.formatDateTime(new Date(m.end_time), "HH:mm");
                                    }
                                    break;
                                }
                            }
                            root.usagePercent = usedPct;
                        }
                    } catch (e) {
                        errorMessage = "Parse error";
                        demoData();
                    }
                } else {
                    errorMessage = "API Error";
                    demoData();
                }
                isLoading = false;
            }
        };

        xhr.onerror = function () {
            errorMessage = "Network error";
            demoData();
            isLoading = false;
        };

        try {
            xhr.send();
        } catch (e) {
            demoData();
            isLoading = false;
        }
    }

    function demoData() {
        var now = new Date();
        lastUpdated = now.toLocaleTimeString(Qt.locale(), "HH:mm");
        root.usagePercent = Math.floor(Math.random() * 60 + 20);
        isLoading = false;
    }

}
