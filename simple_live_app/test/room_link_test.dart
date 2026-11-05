import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/services/room_link_service.dart';

void main() {
  test('accepts supported room identifiers and rejects malformed links', () {
    for (final site in ['huya', 'douyu', 'douyin', 'bilibili']) {
      final link =
          RoomLink.parse(Uri.parse('simplelive://room?site=$site&room=10188'))!;
      expect(link.site, site);
      expect(link.room, '10188');
    }
    for (final url in [
      'https://room?site=huya&room=1',
      'simplelive://room?site=unknown&room=1',
      'simplelive://room?site=huya&room=1&room=2',
      'simplelive://room?site=huya&room=https%3A%2F%2Fevil.example',
      'simplelive://room/extra?site=huya&room=1',
      'simplelive://user@room?site=huya&room=1',
      'simplelive://room?site=huya&room=',
    ]) {
      expect(RoomLink.parse(Uri.parse(url)), isNull, reason: url);
    }
  });

  testWidgets(
      'queues cold-start link until ready, coalesces duplicates and handles warm links',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final opened = <String>[];
    final service =
        RoomLinkService((link) => opened.add('${link.site}/${link.room}'));
    service.start();
    addTearDown(service.dispose);
    Future<bool> send(String url) =>
        service.didPushRouteInformation(RouteInformation(uri: Uri.parse(url)));
    expect(await send('simplelive://room?site=huya&room=10188'), isTrue);
    await tester.pump();
    expect(opened, isEmpty);
    service.markReady();
    await send('simplelive://room?site=huya&room=10188');
    await tester.pump();
    expect(opened, ['huya/10188']);
    await send('simplelive://room?site=douyu&room=998');
    await tester.pump();
    expect(opened.last, 'douyu/998');
    expect(await send('https://example.com'), isFalse);
    expect(await send('simplelive://room?site=invalid&room=1'), isTrue);
    await tester.pump();
    expect(opened.length, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await send('simplelive://room?site=douyu&room=55');
    await tester.pump();
    expect(opened.length, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(opened.last, 'douyu/55');
  });
}
