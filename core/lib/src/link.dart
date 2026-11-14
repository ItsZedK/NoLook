import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'state.dart';
import 'sync.dart';

/// nearby device
class NearbyDevice {
  NearbyDevice({required this.id, required this.name, required this.os, required this.host, required this.port, required this.pairing, required this.seen});

  final String id;
  final String name;
  final String os;
  final String host;
  final int port;

  final bool pairing;
  final DateTime seen;
}

/// pairing code, 10 min, single use
class PairOffer {
  PairOffer(this.code, this.expires);

  final String code;
  final DateTime expires;

  bool get valid => DateTime.now().isBefore(expires);
}

class PairingFailed implements Exception {
  PairingFailed(this.reason);

  /// "code" or "unreachable"
  final String reason;

  @override
  String toString() => 'PairingFailed($reason)';
}

/// wifi pairing + sync, no server. http on [port], udp hello on [beaconPort] so devices
/// find each other after an ip change. syncs are signed with the pairing key.
class NoLookLink {
  NoLookLink({
    required this.state,
    required this.onChanged,
    required this.os,
    this.port = defaultPort,
    this.beaconPort = defaultBeaconPort,
    this.beacon = true,
  });

  static const defaultPort = 47362;
  static const defaultBeaconPort = 47363;

  /// function since the state can be swapped
  final NoLookState Function() state;

  final void Function() onChanged;

  /// "Windows", "Android", ...
  final String os;

  int port;
  final int beaconPort;
  final bool beacon;

  HttpServer? _server;
  RawDatagramSocket? _udp;
  Timer? _hello, _loop, _soon;
  bool _syncing = false;

  PairOffer? offer;
  final nearby = <String, NearbyDevice>{};

  final updates = StreamController<void>.broadcast();

  /// by device id
  final lastSync = <String, DateTime>{};

  bool get running => _server != null;

  Timer? _retry;
  final int _firstPort = defaultPort;

  Future<bool> _bind() async {
    for (var p = _firstPort; p < _firstPort + 10; p++) {
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, p);
        port = p;
        _server!.listen(_handle, onError: (_) {});
        return true;
      } catch (_) {}
    }
    return false;
  }

  Future<void> start() async {
    if (_server != null) return;
    if (port != defaultPort) {
      // custom port, bind just that
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
        _server!.listen(_handle, onError: (_) {});
      } catch (_) {}
    } else if (!await _bind()) {
      // port busy or no network yet, retry
      _retry = Timer.periodic(const Duration(seconds: 30), (t) async {
        if (await _bind()) {
          t.cancel();
          sayHello();
        }
      });
    }
    if (beacon) {
      try {
        _udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, beaconPort, reuseAddress: true)..broadcastEnabled = true;
        _udp!.listen((e) {
          if (e == RawSocketEvent.read) _heard(_udp!.receive());
        });
      } catch (_) {
        // beacon port taken, sending still works
        try {
          _udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0)..broadcastEnabled = true;
        } catch (_) {}
      }
      _hello = Timer.periodic(const Duration(seconds: 4), (_) => sayHello());
      sayHello();
    }
    _loop = Timer.periodic(const Duration(seconds: 20), (_) => syncNow());
    syncNow();
  }

  Future<void> stop() async {
    _retry?.cancel();
    _hello?.cancel();
    _loop?.cancel();
    _soon?.cancel();
    _udp?.close();
    _udp = null;
    await _server?.close(force: true);
    _server = null;
  }

  /// lan addresses, wifi first
  static Future<List<String>> addresses() async {
    final list = <(int, String)>[];
    try {
      for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        final name = i.name.toLowerCase();
        // skip virtual adapters
        if (name.contains('vethernet') || name.contains('virtual') || name.contains('vmware') || name.contains('vbox') || name.contains('tun') || name.contains('wsl')) {
          continue;
        }
        for (final a in i.addresses) {
          final ip = a.address;
          final private = ip.startsWith('192.168.') || ip.startsWith('10.') || RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip);
          if (!private) continue;
          final wifi = name.contains('wi-fi') || name.contains('wlan') || name.contains('wifi') || name.contains('wireless');
          list.add((wifi ? 0 : ip.startsWith('192.168.') ? 1 : 2, ip));
        }
      }
    } catch (_) {}
    list.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final e in list) e.$2];
  }

  // Pairing

  PairOffer openPairing() {
    final r = Random.secure();
    offer = PairOffer(List.generate(6, (_) => r.nextInt(10)).join(), DateTime.now().add(const Duration(minutes: 10)));
    sayHello();
    updates.add(null);
    return offer!;
  }

  void closePairing() {
    offer = null;
    sayHello();
    updates.add(null);
  }

  Future<String> qrText() async {
    final o = offer ?? openPairing();
    final hosts = (await addresses()).take(3).join(',');
    final s = state();
    return Uri(scheme: 'nolook', host: 'pair', queryParameters: {'h': hosts, 'p': '$port', 'c': o.code, 'n': s.deviceName, 'i': s.deviceId}).toString();
  }

  /// null if not ours
  static ({List<String> hosts, int port, String code, String name})? parseQr(String text) {
    final u = Uri.tryParse(text.trim());
    if (u == null || u.scheme != 'nolook' || u.host != 'pair') return null;
    final q = u.queryParameters;
    final hosts = (q['h'] ?? '').split(',').where((h) => h.isNotEmpty).toList();
    final port = int.tryParse(q['p'] ?? '');
    final code = q['c'] ?? '';
    if (hosts.isEmpty || port == null || code.length != 6) return null;
    return (hosts: hosts, port: port, code: code, name: q['n'] ?? '');
  }

  /// tries each host
  Future<PairedDevice> pairWith(List<String> hosts, int port, String code) async {
    final s = state();
    final body = jsonEncode({'code': code, 'id': s.deviceId, 'name': s.deviceName, 'os': os, 'port': this.port});
    for (final host in hosts) {
      final res = await _post(host, port, '/pair', body);
      if (res == null) continue;
      if (res.$1 == 403) throw PairingFailed('code');
      if (res.$1 != 200) continue;
      final j = (jsonDecode(res.$2) as Map).cast<String, Object?>();
      final device = PairedDevice(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        os: j['os'] as String? ?? '',
        key: j['key'] as String,
        host: host,
        port: port,
        lastSeen: DateTime.now(),
      );
      s.paired.removeWhere((p) => p.id == device.id);
      s.paired.add(device);
      onChanged();
      updates.add(null);
      await syncNow();
      return device;
    }
    throw PairingFailed('unreachable');
  }

  /// blocks stay
  void unpair(String id) {
    state().paired.removeWhere((p) => p.id == id);
    lastSync.remove(id);
    onChanged();
    updates.add(null);
  }

  // Syncing

  /// debounced ~1s
  void changedHere() {
    _soon?.cancel();
    _soon = Timer(const Duration(milliseconds: 900), syncNow);
  }

  Future<void> syncNow() async {
    if (_syncing) return;
    _syncing = true;
    try {
      for (final p in List.of(state().paired)) {
        if (p.host.isEmpty) continue;
        await _syncWith(p);
      }
    } finally {
      _syncing = false;
    }
  }

  static String _sign(String key, String body) => Hmac(sha256, utf8.encode(key)).convert(utf8.encode(body)).toString();

  Future<void> _syncWith(PairedDevice p) async {
    final s = state();
    final body = jsonEncode({'from': s.deviceId, 'name': s.deviceName, 'port': port, 'payload': s.syncPayload()});
    final res = await _post(p.host, p.port, '/sync', body, sig: _sign(p.key, body));
    if (res == null || res.$1 != 200) return;
    if (res.$3 != _sign(p.key, res.$2)) return;
    final j = (jsonDecode(res.$2) as Map).cast<String, Object?>();
    p.lastSeen = DateTime.now();
    if (j['name'] is String) p.name = j['name'] as String;
    lastSync[p.id] = DateTime.now();
    s.mergeFrom((j['payload'] as Map).cast());
    onChanged();
    updates.add(null);
  }

  /// null if unreachable
  Future<(int, String, String?)?> _post(String host, int port, String path, String body, {String? sig}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final req = await client.post(host, port, path);
      req.headers.contentType = ContentType.json;
      if (sig != null) req.headers.set('x-nolook-sig', sig);
      req.write(body);
      final res = await req.close().timeout(const Duration(seconds: 8));
      final text = await res.transform(utf8.decoder).join();
      return (res.statusCode, text, res.headers.value('x-nolook-sig'));
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  // The server

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      final body = req.method == 'POST' ? await utf8.decoder.bind(req).join() : '';
      final from = req.connectionInfo?.remoteAddress.address ?? '';
      switch (req.uri.path) {
        case '/hello':
          final s = state();
          _reply(res, 200, jsonEncode({'nolook': 1, 'id': s.deviceId, 'name': s.deviceName, 'os': os, 'pairing': offer?.valid ?? false}));
        case '/pair':
          final j = (jsonDecode(body) as Map).cast<String, Object?>();
          final o = offer;
          if (o == null || !o.valid || j['code'] != o.code) {
            _reply(res, 403, '{}');
            return;
          }
          final s = state();
          final key = base64Url.encode(List.generate(32, (_) => Random.secure().nextInt(256)));
          s.paired.removeWhere((p) => p.id == j['id']);
          s.paired.add(PairedDevice(
            id: j['id'] as String,
            name: j['name'] as String? ?? '',
            os: j['os'] as String? ?? '',
            key: key,
            host: from,
            port: (j['port'] as num? ?? defaultPort).toInt(),
            lastSeen: DateTime.now(),
          ));
          offer = null;
          onChanged();
          updates.add(null);
          _reply(res, 200, jsonEncode({'id': s.deviceId, 'name': s.deviceName, 'os': os, 'key': key}));
        case '/sync':
          final j = (jsonDecode(body) as Map).cast<String, Object?>();
          final s = state();
          final p = s.paired.where((p) => p.id == j['from']).firstOrNull;
          if (p == null || req.headers.value('x-nolook-sig') != _sign(p.key, body)) {
            _reply(res, 403, '{}');
            return;
          }
          // remember its latest address
          if (from.isNotEmpty && from != '127.0.0.1') p.host = from;
          if (j['port'] is num) p.port = (j['port'] as num).toInt();
          if (j['name'] is String) p.name = j['name'] as String;
          p.lastSeen = DateTime.now();
          lastSync[p.id] = DateTime.now();
          s.mergeFrom((j['payload'] as Map).cast());
          onChanged();
          updates.add(null);
          final out = jsonEncode({'name': s.deviceName, 'payload': s.syncPayload()});
          res.headers.set('x-nolook-sig', _sign(p.key, out));
          _reply(res, 200, out);
        default:
          _reply(res, 404, '{}');
      }
    } catch (_) {
      try {
        _reply(res, 400, '{}');
      } catch (_) {}
    }
  }

  void _reply(HttpResponse res, int status, String body) {
    res.statusCode = status;
    res.headers.contentType = ContentType.json;
    res.write(body);
    res.close();
  }

  // Saying hello on the Wi-Fi

  void sayHello() {
    final udp = _udp;
    if (udp == null) return;
    final s = state();
    final msg = utf8.encode(jsonEncode({'nolook': 1, 'id': s.deviceId, 'name': s.deviceName, 'os': os, 'port': port, 'pairing': offer?.valid ?? false}));
    try {
      udp.send(msg, InternetAddress('255.255.255.255'), beaconPort);
    } catch (_) {}
  }

  void _heard(Datagram? d) {
    if (d == null) return;
    try {
      final j = (jsonDecode(utf8.decode(d.data)) as Map).cast<String, Object?>();
      if (j['nolook'] != 1) return;
      final s = state();
      final id = j['id'] as String;
      if (id == s.deviceId) return;
      final host = d.address.address;
      final port = (j['port'] as num).toInt();
      nearby[id] = NearbyDevice(
          id: id, name: j['name'] as String? ?? '', os: j['os'] as String? ?? '', host: host, port: port, pairing: j['pairing'] == true, seen: DateTime.now());
      nearby.removeWhere((_, n) => DateTime.now().difference(n.seen).inSeconds > 15);
      final p = s.paired.where((p) => p.id == id).firstOrNull;
      if (p != null && (p.host != host || p.port != port)) {
        p.host = host;
        p.port = port;
        onChanged();
        _syncWith(p);
      }
      updates.add(null);
    } catch (_) {}
  }
}
