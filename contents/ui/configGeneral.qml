/*
 * Appearance options.
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

KCM.SimpleKCM {
    id: page

    property alias cfg_showWeekNumbers: showWeekNumbers.checked
    property alias cfg_dimPastEvents: dimPastEvents.checked
    property alias cfg_hidePastEvents: hidePastEvents.checked
    property alias cfg_agendaWidth: agendaWidth.value
    property alias cfg_showBackground: showBackground.checked
    property alias cfg_accentColor: accentButton.color
    property alias cfg_useCalendarColors: useCalendarColors.checked

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        RowLayout {
            Kirigami.FormData.label: i18n("Accent color:")
            spacing: Kirigami.Units.smallSpacing

            KQuickControls.ColorButton {
                id: accentButton
                dialogTitle: i18n("Choose accent color")
                showAlphaChannel: false
            }

            // quick picks of colors that stand out well
            Repeater {
                model: ["#f67400", "#ff5722", "#fdbc4b", "#2ecc71", "#e93a9a", "#1d99f3"]

                delegate: Rectangle {
                    required property string modelData

                    implicitWidth: Kirigami.Units.gridUnit
                    implicitHeight: Kirigami.Units.gridUnit
                    radius: Kirigami.Units.cornerRadius
                    color: modelData
                    border.width: swatchMouse.containsMouse ? 2 : 1
                    border.color: Kirigami.Theme.textColor

                    MouseArea {
                        id: swatchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: accentButton.color = parent.modelData
                    }
                }
            }
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            wrapMode: Text.WordWrap
            opacity: 0.7
            font: Kirigami.Theme.smallFont
            text: i18n("Color of the event dots, the agenda bars and the today marker. The standard blue of Plasma is hard to make out on the dark widget background.")
        }

        QQC2.CheckBox {
            id: useCalendarColors
            text: i18n("Use the color of each calendar instead")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: showWeekNumbers
            Kirigami.FormData.label: i18n("Grid:")
            text: i18n("Show week numbers")
        }

        QQC2.CheckBox {
            id: dimPastEvents
            Kirigami.FormData.label: i18n("Past events:")
            text: i18n("Dim")
        }

        QQC2.CheckBox {
            id: hidePastEvents
            text: i18n("Hide completely")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.SpinBox {
            id: agendaWidth
            Kirigami.FormData.label: i18n("Width of the agenda column:")
            from: 150
            to: 900
            stepSize: 10
        }

        QQC2.CheckBox {
            id: showBackground
            Kirigami.FormData.label: i18n("Background:")
            text: i18n("Draw the Plasma background")
        }
    }
}
