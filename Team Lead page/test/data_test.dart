import 'package:creo_teamlead/data.dart';
import 'package:flutter_test/flutter_test.dart';

void reset() {
  tasks.clear();
  clients.clear();
  leaves.clear();
  slots.clear();
  tickets.clear();
  standups.clear();
  memberChats.clear();
  members
    ..clear()
    ..add(me);
}

void main() {
  securityTests();
  setUp(reset);

  Client client() {
    final c = Client('Nexis', 'Growth');
    clients.add(c);
    return c;
  }

  test('load is open tasks against a capacity of 6, capped at 100%', () {
    final c = client();
    final m = addMember('Rajini', 'Editor');
    for (var i = 0; i < 3; i++) {
      assign(title: 't$i', client: c, format: Format.reel, who: m);
    }
    expect(load(m), 50);
    for (var i = 0; i < 5; i++) {
      assign(title: 'x$i', client: c, format: Format.reel, who: m);
    }
    expect(load(m), 100);
    expect(load(me), 0);
  });

  test('approve needs every checklist item ticked', () {
    final t = assign(title: 'Reel', client: client(), format: Format.reel, who: me);
    startTask(t);
    sendToQa(t);
    expect(t.version, 1);
    expect(approve(t), isFalse);
    t.checks.fillRange(0, checklist.length, true);
    expect(approve(t), isTrue);
    expect(t.stage, Stage.dispatched);
  });

  test('a revision goes back to the creative and the next send is v2 with a fresh checklist', () {
    final t = assign(title: 'Reel', client: client(), format: Format.reel, who: me);
    sendToQa(t);
    t.checks[0] = true;
    requestRevision(t, 'Fix the hook');
    expect(t.stage, Stage.progress);
    expect(t.history.last.note, 'Fix the hook');
    sendToQa(t);
    expect(t.version, 2);
    expect(t.checks, everyElement(isFalse));
  });

  test('dispatched work counts toward the client quota this month', () {
    final c = client();
    final t = assign(title: 'Reel', client: c, format: Format.reel, who: me);
    sendToQa(t);
    t.checks.fillRange(0, checklist.length, true);
    approve(t);
    expect(delivered(c, Format.reel), 1);
    expect(burn(c), 1 * 100 ~/ 20);
  });

  test('balance loads moves backlog off an overloaded member to the least loaded', () {
    final c = client();
    final a = addMember('A', 'Editor'), b = addMember('B', 'Designer');
    for (var i = 0; i < 8; i++) {
      assign(title: 't$i', client: c, format: Format.post, who: a);
    }
    expect(balanceLoads(), greaterThan(0));
    expect(openTasks(a).length, lessThanOrEqualTo(capacity));
    expect(openTasks(a).length + openTasks(b).length + openTasks(me).length, 8);
  });

  test('approved leave makes a member inactive today; the lead never decides their own leave', () {
    final m = addMember('Chloe', 'Designer');
    final l = Leave(m, today, today, 'Exam'), mine = Leave(me, today, today, '');
    leaves.addAll([l, mine]);
    expect(toDecide, [l]);
    decide(l, true);
    expect(onLeave(m, today), isTrue);
    expect(activeToday, 1);
  });

  test('only approved, not yet queued work can be scheduled', () {
    final t = assign(title: 'Reel', client: client(), format: Format.reel, who: me);
    expect(readyToSchedule, isEmpty);
    sendToQa(t);
    t.checks.fillRange(0, checklist.length, true);
    approve(t);
    expect(readyToSchedule, [t]);
    slots.add(Slot(t, DateTime.now().add(const Duration(days: 1))));
    expect(readyToSchedule, isEmpty);
  });

  test('csv cells are quoted and formulas are defused', () {
    expect(csvCell('=SUM(A1)'), '"\'=SUM(A1)"');
    expect(csvCell('say "hi"'), '"say ""hi"""');
  });

  test('each pod member gets a direct chat', () {
    addMember('Rajini', 'Editor');
    expect(allChannels.where((c) => !c.group).map((c) => c.name), contains('Rajini'));
  });

  test('day and count words', () {
    expect(dayCount(1), '1 day');
    expect(plural(2, 'task'), '2 tasks');
  });
}

void securityTests() {
  group('rules enforced in data, not only in the UI', () {
    setUp(reset);

    test('the lead cannot decide their own leave, and a decided request stays decided', () {
      final mine = Leave(me, today, today, '');
      final m = addMember('Chloe', 'Designer');
      final theirs = Leave(m, today, today, '');
      leaves.addAll([mine, theirs]);
      expect(decide(mine, true), isFalse);
      expect(mine.status, 'Pending');
      expect(decide(theirs, false), isTrue);
      expect(decide(theirs, true), isFalse);
      expect(theirs.status, 'Rejected');
    });

    test('only approved work, once, at a future time, can be scheduled', () {
      final c = Client('Nexis', 'Growth');
      final t = assign(title: 'Reel', client: c, format: Format.reel, who: me);
      final later = DateTime.now().add(const Duration(days: 1));
      expect(schedule(t, later), isFalse);
      sendToQa(t);
      t.checks.fillRange(0, checklist.length, true);
      approve(t);
      expect(schedule(t, DateTime.now().subtract(const Duration(hours: 1))), isFalse);
      expect(schedule(t, later), isTrue);
      expect(schedule(t, later), isFalse);
      expect(slots.length, 1);
    });

    test('member names must be unique and unlike the picker labels', () {
      addMember('Rajini', 'Editor');
      expect(memberNameProblem(' rajini '), isNotNull);
      expect(memberNameProblem(me.name), isNotNull);
      expect(memberNameProblem('Sam (you)'), isNotNull);
      expect(memberNameProblem('A · B'), isNotNull);
      expect(memberNameProblem('Chloe'), isNull);
      // The lead renaming to a member's name would make the specialist picker ambiguous.
      expect(memberNameProblem('Rajini', except: me), isNotNull);
      expect(memberNameProblem(me.name, except: me), isNull);
    });
  });
}
