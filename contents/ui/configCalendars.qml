/*
 * Selects which Akonadi calendars the widget shows.
 * Pattern taken from:
 *   /usr/lib64/qt6/plugins/plasmacalendarplugins/pimevents/PimEventsConfig.qml
 * Changes take effect right away (saveConfig() directly on toggle).
 * SPDX-License-Identifier: MIT
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels
import org.kde.kirigamiaddons.delegates as Delegates
import org.kde.plasma.PimCalendars

KCM.ScrollViewKCM {
    id: page

    signal configurationChanged

    function saveConfig() {
        calendarModel.saveConfig();
    }

    header: Kirigami.InlineMessage {
        visible: true
        position: Kirigami.InlineMessage.Position.Header
        text: i18n("Choose which of the calendars known to Akonadi appear in the widget. The Radicale calendar has to be ticked.")
    }

    view: ListView {
        id: calendarView

        currentIndex: -1
        clip: true
        focus: true
        activeFocusOnTab: true

        model: KDescendantsProxyModel {
            model: PimCalendarsModel {
                id: calendarModel
            }
        }

        delegate: Delegates.RoundedTreeDelegate {
            id: collection

            required property int collectionId
            required property string name
            required property string iconName
            required property bool isChecked
            required property bool isEnabled

            icon.name: iconName
            text: name

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                QQC2.CheckBox {
                    visible: collection.isEnabled
                    checked: collection.isChecked
                    onToggled: {
                        calendarModel.setChecked(collection.collectionId, checked);
                        calendarModel.saveConfig();
                        page.configurationChanged();
                    }
                }

                Delegates.DefaultContentItem {
                    itemDelegate: collection
                }
            }
        }
    }
}
