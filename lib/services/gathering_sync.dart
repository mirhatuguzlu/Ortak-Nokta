import '../engine/gathering.dart';
import 'group_api.dart';
import 'history_store.dart';

/// Buluşma defterinin nerede tutulduğu: yalnızca bu cihazda ya da davet grubunda (herkes görür).
/// Ekran değişikliği önce kendinde yapar, sonra buraya bildirir.
abstract class GatheringSync {
  Gathering get gathering;

  /// Ortak defterde başkalarının değişikliklerini çeker; yerelde bir şey yapmaz.
  Future<void> reload();
  bool get shared;

  Future<void> addItems(List<BringItem> items);
  Future<void> updateItem(BringItem item);
  Future<void> removeItem(BringItem item);
  Future<void> addExpense(Expense e);
  Future<void> removeExpense(Expense e);
  Future<void> setSpot(String spot);
}

class LocalGathering implements GatheringSync {
  LocalGathering(this.gathering, this.store);
  @override
  final Gathering gathering;
  final HistoryStore store;

  Future<void> _save() => store.saveGathering(gathering);

  @override
  bool get shared => false;
  @override
  Future<void> reload() async {}
  @override
  Future<void> addItems(List<BringItem> items) => _save();
  @override
  Future<void> updateItem(BringItem item) => _save();
  @override
  Future<void> removeItem(BringItem item) => _save();
  @override
  Future<void> addExpense(Expense e) => _save();
  @override
  Future<void> removeExpense(Expense e) => _save();
  @override
  Future<void> setSpot(String spot) => _save();
}

class SharedGathering implements GatheringSync {
  SharedGathering(this.api, this.groupId, this.members)
      : gathering = Gathering('group:$groupId', [for (final m in members) m.label]);
  final GroupApi api;
  final String groupId;
  final List<GroupMember> members;
  @override
  final Gathering gathering;

  String? _uid(String? label) => members.where((m) => m.label == label).firstOrNull?.userId;

  @override
  bool get shared => true;

  @override
  Future<void> reload() async {
    final g = await api.gathering(groupId, members);
    gathering
      ..spot = g.spot
      ..items.clear()
      ..items.addAll(g.items)
      ..expenses.clear()
      ..expenses.addAll(g.expenses);
  }

  @override
  Future<void> addItems(List<BringItem> items) async {
    final ids = await api.addItems(groupId, [for (final i in items) i.name]);
    for (var k = 0; k < items.length; k++) {
      items[k].id = ids[k];
    }
    // Şablondan eklenip hemen birine verilen olmaz; tek eklenen için kişi/işaret de gönderilir.
    for (final i in items.where((i) => i.who != null || i.done)) {
      await updateItem(i);
    }
  }

  @override
  Future<void> updateItem(BringItem item) async {
    final id = item.id;
    if (id != null) await api.setItem(id, _uid(item.who), item.done);
  }

  @override
  Future<void> removeItem(BringItem item) async {
    final id = item.id;
    if (id != null) await api.deleteItem(id);
  }

  @override
  Future<void> addExpense(Expense e) async {
    final payer = _uid(e.payer);
    final forWhom = [for (final p in e.forWhom) _uid(p)];
    if (payer == null || forWhom.contains(null)) {
      throw const FormatException('Gruptan ayrılan biri masrafa eklenemez.');
    }
    e.id = await api.addExpense(groupId, e.what, payer, e.kurus, forWhom.cast<String>());
  }

  @override
  Future<void> removeExpense(Expense e) async {
    final id = e.id;
    if (id != null) await api.deleteExpense(id);
  }

  @override
  Future<void> setSpot(String spot) => api.setSpot(groupId, spot);
}
