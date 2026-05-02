import 'dart:convert';
import '../models/location_context.dart';

/// AlertStorage: Persists alert records locally.
/// Uses shared_preferences (add to pubspec: shared_preferences: ^2.2.2)
/// Falls back to in-memory if unavailable.
class AlertStorage {
  static final AlertStorage _instance = AlertStorage._internal();
  factory AlertStorage() => _instance;
  AlertStorage._internal();

  static const _key = 'alert_records';
  final List<AlertRecord> _memoryStore = [];

  // Uncomment and use with shared_preferences:
  // SharedPreferences? _prefs;
  //
  // Future<void> init() async {
  //   _prefs = await SharedPreferences.getInstance();
  //   _load();
  // }
  //
  // void _load() {
  //   final raw = _prefs?.getStringList(_key) ?? [];
  //   _memoryStore.clear();
  //   for (final s in raw) {
  //     try { _memoryStore.add(AlertRecord.fromJson(jsonDecode(s))); } catch (_) {}
  //   }
  // }

  Future<void> init() async {
    // Seed one demo alert on first launch
    if (_memoryStore.isEmpty) {
      _memoryStore.add(AlertRecord(
        id: 'demo_001',
        timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 14)),
        position: const LatLng(12.9716, 77.5946),
        riskScore: 87,
        triggerSource: 'Auto (Predicted)',
        activeSignals: ['Stationary 4.2min', 'Unknown area', 'Late night (10pm–5am)'],
      ));
    }
  }

  Future<void> save(AlertRecord record) async {
    _memoryStore.insert(0, record);

    // Uncomment for persistence:
    // final list = _memoryStore.map((r) => jsonEncode(r.toJson())).toList();
    // await _prefs?.setStringList(_key, list);
  }

  List<AlertRecord> getAll() => List.unmodifiable(_memoryStore);

  Future<void> clear() async {
    _memoryStore.clear();
    // await _prefs?.remove(_key);
  }
}