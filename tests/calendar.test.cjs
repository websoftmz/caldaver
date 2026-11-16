const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const ui = path.join(__dirname, '../contents/ui');
const main = fs.readFileSync(path.join(ui, 'main.qml'), 'utf8');
const agendaSource = fs.readFileSync(path.join(ui, 'AgendaList.qml'), 'utf8');

// Execute the actual QML JavaScript, replacing only Qt models and the clock.
function functionSource(source, name) {
    const match = source.match(new RegExp(`^    function ${name}\\([^]*?^    }`, 'm'));
    assert.ok(match, `Missing QML function: ${name}`);
    return match[0];
}

function listModel() {
    return {
        rows: [],
        get count() { return this.rows.length; },
        get(i) { return this.rows[i]; },
        append(row) { this.rows.push(row); },
        clear() { this.rows = []; },
        remove(i) { this.rows.splice(i, 1); },
        setProperty(i, key, value) { this.rows[i][key] = value; }
    };
}

function fixture() {
    let now = new Date(2026, 5, 15, 10).getTime();
    class ClockDate extends Date {
        constructor(...args) { super(...(args.length ? args : [now])); }
    }
    const later = [];
    const positions = [];
    const context = {
        Date: ClockDate,
        Qt: {locale: () => 'en-GB', callLater: callback => later.push(callback)},
        ListView: {Beginning: 0},
        view: {positionViewAtIndex: i => positions.push(i)},
        backend: {
            year: 2026, month: 6,
            daysModel: {indexOfFirstCurrentEntry: 7, eventsForDate: () => []},
            resetToToday() { this.year = 2026; this.month = 6; }
        },
        Plasmoid: {configuration: {hidePastEvents: false}},
        root: {today: new ClockDate(), selectedKey: '', pendingScrollKey: ''},
        dayGridModel: listModel(),
        monthAgendaModel: listModel(),
        i18n: text => text,
        rebuildTimer: {restart() { this.scheduled = true; }}
    };
    vm.createContext(context);
    for (const name of ['dateKey', 'computeGridStart', 'eventSignature', 'eventsForDay',
                        'rebuild', 'updatePastEvents', 'scheduleRebuild']) {
        vm.runInContext(functionSource(main, name), context);
        context.root[name] = context[name];
    }
    context.agenda = {agendaModel: context.monthAgendaModel};
    vm.runInContext(functionSource(agendaSource, 'scrollToKey'), context);
    context.root.fullRepresentationItem = {scrollToKey: context.scrollToKey};
    return Object.assign(context, {
        positions,
        advanceTo: value => { now = value.getTime(); },
        flushLater: () => { while (later.length) later.shift()(); }
    });
}

function event(overrides = {}) {
    return {
        title: 'Meeting', description: '', isAllDay: false, eventColor: '#123456',
        startDateTime: new Date(2026, 5, 15, 10),
        endDateTime: new Date(2026, 5, 15, 11),
        ...overrides
    };
}

function eventsOnJune15(context, events) {
    context.backend.daysModel.eventsForDate = date =>
        date.getMonth() === 5 && date.getDate() === 15 ? events : [];
}

test('grid follows backend offsets across months, week starts and leap years', () => {
    const c = fixture();
    for (const year of [2024, 2026]) {
        for (let month = 1; month <= 12; ++month) {
            for (let firstDay = 0; firstDay < 7; ++firstDay) {
                const delta = (new Date(year, month - 1, 1).getDay() - firstDay + 7) % 7;
                const offset = delta || 7; // Plasma includes the previous week.
                Object.assign(c.backend, {year, month});
                c.backend.daysModel.indexOfFirstCurrentEntry = offset;
                c.rebuild();
                const start = new Date(year, month - 1, 1 - offset);
                assert.equal(c.dayGridModel.count, 42);
                assert.equal(c.dayGridModel.get(0).key, c.dateKey(start));
                assert.equal(start.getDay(), firstDay);
                assert.equal(c.dayGridModel.get(offset).dayNum, 1);
                assert.equal(c.dayGridModel.get(offset).inMonth, true);
                assert.equal(new Set(c.dayGridModel.rows.map(row => row.key)).size, 42);
                c.flushLater();
            }
        }
    }
});

test('distinct text fields survive while identical deliveries are deduplicated', () => {
    const c = fixture();
    const first = event({title: 'A B', description: 'C'});
    const second = event({title: 'A', description: 'B C'});
    eventsOnJune15(c, [first, second, {...first}]);
    c.rebuild();
    assert.equal(c.monthAgendaModel.count, 2);
    assert.notEqual(c.eventSignature(first), c.eventSignature(second));
});

test('all-day events sort before timed events, followed by start time', () => {
    const c = fixture();
    eventsOnJune15(c, [event(), event({title: 'All day', isAllDay: true}),
        event({title: 'Early', startDateTime: new Date(2026, 5, 15, 8)})]);
    c.rebuild();
    assert.deepEqual(c.monthAgendaModel.rows.map(row => row.title), ['All day', 'Early', 'Meeting']);
});

test('time status updates in place, including after a backwards clock adjustment', () => {
    const c = fixture();
    eventsOnJune15(c, [event()]);
    c.rebuild();
    const rows = c.monthAgendaModel.rows;
    assert.equal(rows[0].isPast, false);
    c.advanceTo(new Date(2026, 5, 15, 12));
    c.updatePastEvents();
    assert.equal(c.monthAgendaModel.rows, rows);
    assert.equal(rows[0].isPast, true);
    c.advanceTo(new Date(2026, 5, 15, 10));
    c.updatePastEvents();
    assert.equal(rows[0].isPast, false);
});

test('minute timer refreshes expired events and rebuilds at midnight', () => {
    const c = fixture();
    eventsOnJune15(c, [event()]);
    c.rebuild();
    const timer = main.slice(main.indexOf('interval: 60000'));
    const handler = timer.match(/onTriggered: \{([^]*?)^        }/m);
    assert.ok(handler);
    const tick = vm.runInContext(`(function () {${handler[1]}})`, c);
    c.advanceTo(new Date(2026, 5, 15, 12));
    tick();
    assert.equal(c.monthAgendaModel.get(0).isPast, true);
    assert.equal(c.rebuildTimer.scheduled, undefined);
    c.advanceTo(new Date(2026, 5, 16, 0, 1));
    tick();
    assert.equal(c.dateKey(c.root.today), '2026-06-16');
    assert.equal(c.rebuildTimer.scheduled, true);
});

test('hiding expired events removes consecutive rows and keeps future entries', () => {
    const c = fixture();
    c.Plasmoid.configuration.hidePastEvents = true;
    eventsOnJune15(c, [event(), event({title: 'Second'}),
        event({title: 'Future', endDateTime: new Date(2026, 5, 15, 14)})]);
    c.rebuild();
    assert.equal(c.monthAgendaModel.count, 3);
    c.advanceTo(new Date(2026, 5, 15, 12));
    c.updatePastEvents();
    assert.deepEqual(c.monthAgendaModel.rows.map(row => row.title), ['Future']);
    c.Plasmoid.configuration.hidePastEvents = false;
    c.rebuild();
    assert.equal(c.monthAgendaModel.count, 3);
    assert.equal(c.monthAgendaModel.get(0).isPast, true);
});

test('Today waits for a rebuilt model and delayed calendar data before scrolling', () => {
    const c = fixture();
    c.backend.month = 5;
    c.monthAgendaModel.append({key: '2026-05-15'});
    const button = main.slice(main.indexOf('text: i18n("Today")'));
    const handler = button.match(/onClicked: \{([^]*?)^                    }/m);
    assert.ok(handler);
    vm.runInContext(handler[1], c);
    assert.equal(c.root.selectedKey, '2026-06-15');
    assert.equal(c.rebuildTimer.scheduled, true);
    assert.equal(c.positions.length, 0);
    c.rebuild();
    c.flushLater();
    assert.equal(c.root.pendingScrollKey, '2026-06-15');
    eventsOnJune15(c, [event()]);
    c.rebuild();
    assert.equal(c.positions.length, 0);
    c.flushLater();
    assert.deepEqual(c.positions, [0]);
    assert.equal(c.root.pendingScrollKey, '');
});

test('Today scroll remains pending until the visual representation is available', () => {
    const c = fixture();
    eventsOnJune15(c, [event()]);
    c.root.pendingScrollKey = '2026-06-15';
    const representation = c.root.fullRepresentationItem;
    c.root.fullRepresentationItem = null;
    c.rebuild();
    c.flushLater();
    assert.equal(c.root.pendingScrollKey, '2026-06-15');
    c.root.fullRepresentationItem = representation;
    c.rebuild();
    c.flushLater();
    assert.deepEqual(c.positions, [0]);
    assert.equal(c.root.pendingScrollKey, '');
});

test('scrolling selects the first entry of the requested day only', () => {
    const c = fixture();
    for (const key of ['2026-06-14', '2026-06-15', '2026-06-15']) {
        c.monthAgendaModel.append({key});
    }
    assert.equal(c.scrollToKey('2026-06-15'), true);
    assert.deepEqual(c.positions, [1]);
    assert.equal(c.scrollToKey('2026-06-16'), false);
    c.agenda.agendaModel = null;
    assert.equal(c.scrollToKey('2026-06-15'), false);
});
