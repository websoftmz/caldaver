/*
 * Agenda column: every event of the displayed month, grouped by day.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

Item {
    id: agenda

    property var agendaModel: null
    property bool dimPast: true
    property string selectedKey: ""
    property string todayKey: ""
    property color accentColor: "#f67400"
    property bool useCalendarColors: false

    // Jumps to the first entry of the given day.
    function scrollToKey(key) {
        if (!agenda.agendaModel) {
            return false;
        }
        for (let i = 0; i < agenda.agendaModel.count; ++i) {
            if (agenda.agendaModel.get(i).key === key) {
                view.positionViewAtIndex(i, ListView.Beginning);
                return true;
            }
        }
        return false;
    }

    PlasmaComponents.ScrollView {
        anchors.fill: parent

        ListView {
            id: view

            model: agenda.agendaModel
            clip: true
            spacing: 0

            section.property: "key"
            section.criteria: ViewSection.FullString
            section.delegate: Item {
                id: sectionRoot

                required property string section

                width: view.width
                height: sectionLabel.implicitHeight + Kirigami.Units.smallSpacing * 2

                Kirigami.Heading {
                    id: sectionLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    level: 5
                    opacity: 0.7
                    textFormat: Text.PlainText
                    // section is "YYYY-MM-DD"; reformat it for display
                    text: {
                        const parts = sectionRoot.section.split("-");
                        const d = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
                        return d.toLocaleDateString(Qt.locale(), "dddd, d MMMM");
                    }
                    font.bold: sectionRoot.section === agenda.todayKey
                }

                Kirigami.Separator {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                }
            }

            delegate: Item {
                id: row

                required property string key
                required property string timeLabel
                required property string title
                required property string description
                required property string endLabel
                required property string eventColor
                required property bool isPast

                // No calendar color, or calendar colors turned off -> accent color
                readonly property color barColor:
                    (agenda.useCalendarColors && row.eventColor.length > 0)
                        ? row.eventColor : agenda.accentColor

                width: view.width
                height: rowLayout.implicitHeight + Kirigami.Units.smallSpacing * 2
                opacity: (row.isPast && agenda.dimPast) ? 0.45 : 1.0

                Rectangle {
                    anchors.fill: parent
                    color: Qt.alpha(agenda.accentColor, 0.15)
                    visible: row.key === agenda.selectedKey
                }

                RowLayout {
                    id: rowLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Kirigami.Units.smallSpacing

                    Rectangle {
                        Layout.preferredWidth: 3
                        Layout.fillHeight: true
                        Layout.minimumHeight: Kirigami.Units.gridUnit
                        radius: 1.5
                        color: row.barColor
                    }

                    PlasmaComponents.Label {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        opacity: 0.8
                        text: row.timeLabel
                    }

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        text: row.title
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                }

                PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                PlasmaComponents.ToolTip.visible: rowMouse.containsMouse
                PlasmaComponents.ToolTip.text: {
                    let t = row.title;
                    if (row.endLabel.length > 0) {
                        t += "\n" + row.timeLabel + " – " + row.endLabel;
                    }
                    if (row.description.length > 0) {
                        t += "\n\n" + row.description;
                    }
                    return t;
                }
            }
        }
    }

    // Empty state
    PlasmaExtras.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 2
        visible: !agenda.agendaModel || agenda.agendaModel.count === 0
        iconName: "office-calendar"
        text: i18n("No events this month")
        explanation: i18n("If events are missing, check under \"Calendars\" in the widget settings whether the desired calendar is enabled.")
    }
}
