/*
 * Month grid: 7 columns x 6 rows, events indicated by colored dots.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: grid

    property var gridModel: null       // ListModel with 42 entries
    property var weeksModel: []        // Array<int>, week numbers
    property int firstDayOfWeek: 1
    property bool showWeekNumbers: false
    property string selectedKey: ""
    property color accentColor: "#f67400"
    property bool useCalendarColors: false

    signal dayClicked(string key)

    readonly property int columnCount: 7 + (showWeekNumbers ? 1 : 0)
    readonly property real sideColumnWidth: width / columnCount

    // Black or white - whichever is readable on the accent color.
    readonly property color accentTextColor:
        (0.299 * accentColor.r + 0.587 * accentColor.g + 0.114 * accentColor.b) > 0.6
            ? "#000000" : "#ffffff"

    // "-" in the model means: the event has no calendar color of its own.
    function markerColor(raw) {
        return (grid.useCalendarColors && raw !== "-") ? raw : grid.accentColor;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---- names of the weekdays ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            // placeholder above the week number column
            Item {
                visible: grid.showWeekNumbers
                Layout.preferredWidth: grid.sideColumnWidth
                Layout.preferredHeight: Kirigami.Units.gridUnit
            }

            Repeater {
                model: 7
                delegate: Kirigami.Heading {
                    required property int index

                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit
                    level: 5
                    opacity: 0.7
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: Qt.locale().dayName((grid.firstDayOfWeek + index) % 7, Locale.ShortFormat)
                }
            }
        }

        // ---- the 6 week rows ----
        Repeater {
            model: 6
            delegate: RowLayout {
                id: weekRowLayout

                required property int index
                readonly property int weekRow: index

                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // week number
                PlasmaComponents.Label {
                    visible: grid.showWeekNumbers
                    Layout.preferredWidth: grid.sideColumnWidth
                    Layout.fillHeight: true
                    opacity: 0.5
                    font.italic: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    textFormat: Text.PlainText
                    text: (grid.weeksModel && grid.weeksModel.length > weekRowLayout.weekRow)
                        ? grid.weeksModel[weekRowLayout.weekRow] : ""
                }

                Repeater {
                    model: 7
                    delegate: Item {
                        id: cell

                        required property int index
                        readonly property int cellIndex: weekRowLayout.weekRow * 7 + index
                        readonly property var entry: (grid.gridModel && grid.gridModel.count > cellIndex)
                            ? grid.gridModel.get(cellIndex) : null

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        // background: today / selected / hover
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: Kirigami.Units.cornerRadius
                            color: {
                                if (!cell.entry) {
                                    return "transparent";
                                }
                                if (cell.entry.isToday) {
                                    return grid.accentColor;
                                }
                                if (cell.entry.key === grid.selectedKey) {
                                    return Qt.alpha(grid.accentColor, 0.35);
                                }
                                if (cellMouse.containsMouse) {
                                    return Qt.alpha(grid.accentColor, 0.15);
                                }
                                return "transparent";
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 1

                            PlasmaComponents.Label {
                                Layout.alignment: Qt.AlignHCenter
                                textFormat: Text.PlainText
                                text: cell.entry ? cell.entry.dayNum : ""
                                opacity: (cell.entry && cell.entry.inMonth) ? 1.0 : 0.35
                                font.bold: cell.entry ? cell.entry.isToday : false
                                color: (cell.entry && cell.entry.isToday)
                                    ? grid.accentTextColor
                                    : Kirigami.Theme.textColor
                            }

                            // event indicators
                            Row {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 2
                                height: Kirigami.Units.smallSpacing

                                Repeater {
                                    // dotColors is a " " separated string
                                    model: (cell.entry && cell.entry.dotColors.length > 0)
                                        ? cell.entry.dotColors.split(" ") : []

                                    delegate: Rectangle {
                                        required property string modelData
                                        width: Kirigami.Units.smallSpacing
                                        height: width
                                        radius: width / 2
                                        color: {
                                            const c = grid.markerColor(modelData);
                                            // On the today cell the accent color is
                                            // already the background - draw against it.
                                            return (cell.entry && cell.entry.isToday
                                                    && Qt.colorEqual(c, grid.accentColor))
                                                ? grid.accentTextColor : c;
                                        }
                                        opacity: (cell.entry && cell.entry.inMonth) ? 1.0 : 0.4
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: cellMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: cell.entry !== null
                            onClicked: {
                                if (cell.entry) {
                                    grid.dayClicked(cell.entry.key);
                                }
                            }
                        }

                        PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                        PlasmaComponents.ToolTip.visible: cellMouse.containsMouse
                            && cell.entry !== null && cell.entry.eventCount > 0
                        PlasmaComponents.ToolTip.text: cell.entry
                            ? i18np("%1 event", "%1 events", cell.entry.eventCount) : ""
                    }
                }
            }
        }
    }
}
