import 'package:flutter/widgets.dart';

/// Only room identifiers are accepted; never execute arbitrary links or routes.
class RoomLink {
  final String site;
  final String room;
  const RoomLink(this.site, this.room);

  static RoomLink? parse(Uri uri) {
    if (uri.scheme != 'simplelive' ||
        uri.host != 'room' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      return null;
    }
    final sites = uri.queryParametersAll['site'];
    final rooms = uri.queryParametersAll['room'];
    if (sites?.length != 1 || rooms?.length != 1) return null;
    final site = sites!.single, room = rooms!.single;
    if (!['huya', 'douyu', 'douyin', 'bilibili'].contains(site) ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(room)) {
      return null;
    }
    return RoomLink(site, room);
  }
}

/// Listen before async initialization; open only after the navigator is ready.
/// Uses Flutter's built-in iOS link delivery, without another native plugin.
class RoomLinkService with WidgetsBindingObserver {
  final void Function(RoomLink) onOpen;
  RoomLinkService(this.onOpen);
  RoomLink? _pending;
  bool _ready = false, _scheduled = false, _disposed = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    final uri = Uri.tryParse(
        WidgetsBinding.instance.platformDispatcher.defaultRouteName);
    if (uri != null) _accept(uri);
  }

  void markReady() {
    _ready = true;
    _drain();
  }

  bool _accept(Uri uri) {
    if (uri.scheme != 'simplelive') return false;
    final link = RoomLink.parse(uri);
    if (link != null) {
      _pending = link;
      _drain();
    }
    // Consume malformed links for our scheme so they cannot become app routes.
    return true;
  }

  void _drain() {
    if (_disposed || !_ready || _pending == null || _scheduled) return;
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed) return;
      final state = WidgetsBinding.instance.lifecycleState;
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.detached) {
        return;
      }
      final link = _pending;
      _pending = null;
      if (link != null) onOpen(link);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Future<bool> didPushRouteInformation(
          RouteInformation routeInformation) async =>
      _accept(routeInformation.uri);

  @override
  Future<bool> didPushRoute(String route) async {
    final uri = Uri.tryParse(route);
    return uri != null && _accept(uri);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _drain();
  }

  void dispose() {
    _disposed = true;
    _pending = null;
    WidgetsBinding.instance.removeObserver(this);
  }
}
