import QtQuick
import QtQuick.Layouts as QtLayouts
import QtQuick.Controls as QtControls
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid

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
                text: usagePercent + "%"
                font.pixelSize: 14
                font.bold: true
                color: textColor
            }

            Timer {
                interval: config_refreshInterval * 1000
                repeat: true
                onTriggered: fetchData()
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
                    text : "usage : " + usagePercent + "% / 100%"
                }
                QtControls.ProgressBar{
                    id : progress
                    QtLayouts.Layout.alignment: Qt.AlignCenter
                    implicitHeight: 20
                    padding: 0
                    from: 0
                    to: 100
                    value: usagePercent          // green = used, grows with consumption
                    background: Rectangle {
                        implicitHeight: 20
                        color: bgColor
                        radius: 3
                    }

                    contentItem: Item {
                        implicitHeight: 20
                        clip: true

                        Rectangle {
                            width: progress.visualPosition * parent.width
                            height: parent.height
                            color: barColor
                            radius: 3
                        }
                    }
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
                var now = new Date();
                lastUpdated = now.toLocaleTimeString(Qt.locale(), "HH:mm");

                if (xhr.status === 200) {
                    try {
                        var resp = JSON.parse(xhr.responseText);
                        if (resp.model_remains) {
                            var usedPct = 0;
                            for (var i = 0; i < resp.model_remains.length; i++) {
                                var m = resp.model_remains[i];
                                // "general" = aggregate LLM token quota
                                // (API no longer exposes MiniMax-M* family names)
                                if (m.model_name === "general") {
                                    var remainingPct = m.current_interval_remaining_percent;
                                    var remaining = (typeof remainingPct === "number") ? remainingPct : 100;
                                    usedPct = 100 - remaining;
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
