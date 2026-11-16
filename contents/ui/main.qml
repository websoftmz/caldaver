/*
 * caldaver - Plasma 6 applet
 * SPDX-License-Identifier: MIT
 *
 * Data source: Akonadi via the Plasma calendar plugin "pimevents".
 * The 42 day grid is computed in JavaScript, the events come from
 * daysModel.eventsForDate(). daysModel is deliberately NOT used as a
 * repeater model directly - it is a tree model.
 */
import QtQuick
import QtQml
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.calendar as PlasmaCalendar

PlasmoidItem {
    id: root

    // ------------------------------------------------------------------ State
    property date today: new Date()
    property string selectedKey: ""     // "YYYY-MM-DD" of the clicked day
    property string pendingScrollKey: ""

    // Accent color of the widget. Used for the event dots, the agenda color
    // bars, the today highlight and the day selection. The default is orange,
    // because the standard blue is hard to make out on the dark widget
    // background.
    readonly property color accentColor: Plasmoid.configuration.accentColor
    readonly property bool useCalendarColors: Plasmoid.configuration.useCalendarColors

    // -------------------------------------------------------------- Size/look
    preferredRepresentation: fullRepresentation

    Plasmoid.backgroundHints: Plasmoid.configuration.showBackground
        ? PlasmaCore.Types.DefaultBackground
        : PlasmaCore.Types.NoBackground

    Layout.minimumWidth: Kirigami.Units.gridUnit * 26
    Layout.minimumHeight: Kirigami.Units.gridUnit * 15
    Layout.preferredWidth: Kirigami.Units.gridUnit * 42
    Layout.preferredHeight: Kirigami.Units.gridUnit * 22

    // ---------------------------------------------------------------- Helpers
    function dateKey(d) {
        const m = d.getMonth() + 1;
        const day = d.getDate();
        return d.getFullYear() + "-" + (m < 10 ? "0" + m : m) + "-" + (day < 10 ? "0" + day : day);
    }

    // Use the backend's offset so the dates match its week numbers and range.
    function computeGridStart() {
        return new Date(backend.year, backend.month - 1,
                        1 - backend.daysModel.indexOfFirstCurrentEntry);
    }

    // Identity of an event, used to drop duplicates handed out by DaysModel.
    // EventDataDecorator exposes no UID, so the visible payload has to serve as
    // the identity. Two entries that agree on all of it are indistinguishable
    // in this widget anyway.
    function eventSignature(ev) {
        return JSON.stringify([ev.title,
                ev.description,
                ev.isAllDay,
                ev.eventColor,
                ev.startDateTime ? ev.startDateTime.getTime() : "",
                ev.endDateTime ? ev.endDateTime.getTime() : ""]);
    }

    // Events of one day: duplicates removed, all day ones first, then in
    // chronological order.
    //
    // The de-duplication is what keeps every appointment from showing up twice.
    // DaysModel merges each delivery of plugin data into its event hash without
    // discarding the previous one, so whenever the pimevents plugin reports the
    // same date range more than once - which is what happens while Akonadi is
    // still starting up and brings its collections online one after another -
    // eventsForDate() returns every event once per delivery. Anything that made
    // DaysModel reload from scratch (month navigation, the today button,
    // reopening the settings) cleared that up until the next cold start;
    // filtering here fixes it for good.
    function eventsForDay(d) {
        const raw = backend.daysModel.eventsForDate(d) || [];
        const seen = new Set();
        const evts = [];

        for (let i = 0; i < raw.length; ++i) {
            const sig = root.eventSignature(raw[i]);
            if (seen.has(sig)) {
                continue;
            }
            seen.add(sig);
            evts.push(raw[i]);
        }

        return evts.sort(function (a, b) {
            if (a.isAllDay !== b.isAllDay) {
                return a.isAllDay ? -1 : 1;
            }
            return a.startDateTime.getTime() - b.startDateTime.getTime();
        });
    }

    // ----------------------------------------------------------------- Models
    // The ids differ from the equally named properties of the child components
    // on purpose, otherwise "gridModel: gridModel" would refer to itself.
    ListModel { id: dayGridModel }      // exactly 42 entries (6 weeks x 7 days)
    ListModel { id: monthAgendaModel }  // events of the displayed month, in order

    // Rebuilds both models from scratch.
    function rebuild() {
        const start = computeGridStart();
        const todayKey = dateKey(root.today);
        const nowMs = new Date().getTime();

        dayGridModel.clear();
        monthAgendaModel.clear();

        for (let i = 0; i < 42; ++i) {
            const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
            const evts = root.eventsForDay(d);

            // --- grid cell ---
            // Only remember the raw color of the calendar, "-" means "no color
            // of its own". Which color ends up being drawn is decided by the
            // delegate based on the accent color - that way a color change
            // takes effect without a rebuild.
            const colors = [];
            for (let k = 0; k < Math.min(evts.length, 5); ++k) {
                const c = evts[k].eventColor;
                colors.push((c && c.length > 0) ? c : "-");
            }

            const inMonth = (d.getMonth() + 1) === backend.month;

            dayGridModel.append({
                "dayNum": d.getDate(),
                "key": dateKey(d),
                "inMonth": inMonth,
                "isToday": dateKey(d) === todayKey,
                "eventCount": evts.length,
                // Space separated string, because ListModel cannot store
                // JS string arrays. Read it with split(" ") in the delegate.
                "dotColors": colors.join(" ")
            });

            // --- agenda: only days of the displayed month ---
            if (!inMonth) {
                continue;
            }
            for (let j = 0; j < evts.length; ++j) {
                const ev = evts[j];
                const endMs = ev.endDateTime ? ev.endDateTime.getTime() : ev.startDateTime.getTime();
                const past = endMs < nowMs;

                if (Plasmoid.configuration.hidePastEvents && past) {
                    continue;
                }

                monthAgendaModel.append({
                    "key": dateKey(d),
                    "timeLabel": ev.isAllDay
                        ? i18n("all day")
                        : ev.startDateTime.toLocaleTimeString(Qt.locale(), "hh:mm"),
                    "title": ev.title,
                    "description": ev.description ? ev.description : "",
                    "endLabel": ev.isAllDay
                        ? ""
                        : ev.endDateTime.toLocaleTimeString(Qt.locale(), "hh:mm"),
                    "eventColor": (ev.eventColor && ev.eventColor.length > 0) ? ev.eventColor : "",
                    "isPast": past,
                    "endMs": endMs
                });
            }
        }

        Qt.callLater(function () {
            if (root.pendingScrollKey !== "" && root.fullRepresentationItem
                    && root.fullRepresentationItem.scrollToKey(root.pendingScrollKey)) {
                root.pendingScrollKey = "";
            }
        });
    }

    // Update time-dependent roles without resetting the agenda's scroll position.
    function updatePastEvents() {
        const nowMs = new Date().getTime();
        for (let i = monthAgendaModel.count - 1; i >= 0; --i) {
            const past = monthAgendaModel.get(i).endMs < nowMs;
            if (Plasmoid.configuration.hidePastEvents && past) {
                monthAgendaModel.remove(i);
            } else {
                monthAgendaModel.setProperty(i, "isPast", past);
            }
        }
    }

    // Coalesce several agendaUpdated signals in quick succession into one rebuild
    Timer {
        id: rebuildTimer
        interval: 200
        repeat: false
        onTriggered: root.rebuild()
    }
    function scheduleRebuild() {
        rebuildTimer.restart();
    }

    // ------------------------------------------------------------ Data source
    PlasmaCalendar.EventPluginsManager {
        id: pluginsManager

        // The identifier is the KPluginMetaData pluginId (file name without
        // extension), confirmed on this system by diagnostics as "pimevents".
        // Careful: a full .so path is NOT accepted and leads to
        // "Could not load Plasma Calendar Plugin" in the journal.
        enabledPlugins: ["pimevents"]
    }

    // Diagnostic helper: lists the calendar plugins found, with their id.
    // Watch it with: journalctl --user -f | grep caldaver
    Instantiator {
        model: pluginsManager.model
        delegate: QtObject {
            required property string pluginId
            Component.onCompleted: console.warn("[caldaver] calendar plugin available:",
                                                pluginId)
        }
    }

    PlasmaCalendar.Calendar {
        id: backend

        days: 7
        weeks: 6
        firstDayOfWeek: Qt.locale().firstDayOfWeek
        today: root.today
        types: PlasmaCalendar.Calendar.Event | PlasmaCalendar.Calendar.Holiday

        Component.onCompleted: {
            daysModel.setPluginsManager(pluginsManager);
            root.selectedKey = root.dateKey(root.today);
            root.scheduleRebuild();
        }

        onDisplayedDateChanged: root.scheduleRebuild()
    }

    Connections {
        target: backend.daysModel

        function onAgendaUpdated(updatedDate) { root.scheduleRebuild(); }
        function onDataChanged() { root.scheduleRebuild(); }
        function onModelReset() { root.scheduleRebuild(); }
    }

    Connections {
        target: pluginsManager
        function onPluginsChanged() { root.scheduleRebuild(); }
    }

    // Refresh expired events each minute and notice the date change at midnight.
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            const now = new Date();
            if (now.toDateString() !== root.today.toDateString()) {
                root.today = now;
                root.scheduleRebuild();
            } else {
                root.updatePastEvents();
            }
        }
    }

    // Make a change to "hide past events" take effect right away
    Connections {
        target: Plasmoid.configuration
        function onHidePastEventsChanged() { root.scheduleRebuild(); }
    }

    // ------------------------------------------------------------------ Layout
    fullRepresentation: Item {
        function scrollToKey(key) {
            return agendaList.scrollToKey(key);
        }

        // These values determine the size the widget is first dropped onto the
        // desktop with - not the one of the PlasmoidItem root object.
        Layout.minimumWidth: Kirigami.Units.gridUnit * 26
        Layout.minimumHeight: Kirigami.Units.gridUnit * 15
        Layout.preferredWidth: Kirigami.Units.gridUnit * 46
        Layout.preferredHeight: Kirigami.Units.gridUnit * 26

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            // ---- header row: month navigation ----
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.ToolButton {
                    icon.name: "go-previous-symbolic"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    text: i18n("Previous month")
                    PlasmaComponents.ToolTip.text: text
                    PlasmaComponents.ToolTip.visible: hovered
                    onClicked: {
                        root.pendingScrollKey = "";
                        backend.previousMonth();
                    }
                }

                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 2
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: backend.monthName + " " + backend.year
                }

                PlasmaComponents.ToolButton {
                    icon.name: "go-next-symbolic"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    text: i18n("Next month")
                    PlasmaComponents.ToolTip.text: text
                    PlasmaComponents.ToolTip.visible: hovered
                    onClicked: {
                        root.pendingScrollKey = "";
                        backend.nextMonth();
                    }
                }

                PlasmaComponents.Label {
                    text: "v" + Plasmoid.metaData.version
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                }

                PlasmaComponents.ToolButton {
                    icon.name: "go-jump-today-symbolic"
                    display: PlasmaComponents.AbstractButton.IconOnly
                    text: i18n("Today")
                    PlasmaComponents.ToolTip.text: text
                    PlasmaComponents.ToolTip.visible: hovered
                    onClicked: {
                        root.today = new Date();
                        backend.resetToToday();
                        root.selectedKey = root.dateKey(root.today);
                        root.pendingScrollKey = root.selectedKey;
                        root.scheduleRebuild();
                    }
                }
            }

            // ---- main area: grid + agenda ----
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Kirigami.Units.largeSpacing

                MonthGrid {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 14

                    gridModel: dayGridModel
                    weeksModel: backend.weeksModel
                    firstDayOfWeek: backend.firstDayOfWeek
                    showWeekNumbers: Plasmoid.configuration.showWeekNumbers
                    selectedKey: root.selectedKey
                    accentColor: root.accentColor
                    useCalendarColors: root.useCalendarColors

                    onDayClicked: function (key) {
                        root.pendingScrollKey = "";
                        root.selectedKey = key;
                        agendaList.scrollToKey(key);
                    }
                }

                Kirigami.Separator {
                    Layout.fillHeight: true
                }

                AgendaList {
                    id: agendaList
                    Layout.preferredWidth: Plasmoid.configuration.agendaWidth
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 10
                    Layout.fillHeight: true

                    agendaModel: monthAgendaModel
                    dimPast: Plasmoid.configuration.dimPastEvents
                    selectedKey: root.selectedKey
                    todayKey: root.dateKey(root.today)
                    accentColor: root.accentColor
                    useCalendarColors: root.useCalendarColors
                }
            }
        }
    }
}
