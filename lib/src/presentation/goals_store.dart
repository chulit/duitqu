import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Model ringan untuk tujuan nabung (UI mockup; v4 boleh ganti).
class SavingGoal {
  final String id;
  final String name;
  final int target;
  final int saved;
  final int color;

  const SavingGoal({
    required this.id,
    required this.name,
    required this.target,
    required this.saved,
    required this.color,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'target': target,
    'saved': saved,
    'color': color,
  };

  factory SavingGoal.fromJson(Map<String, dynamic> j) => SavingGoal(
    id: j['id'] as String,
    name: j['name'] as String,
    target: (j['target'] as num).toInt(),
    saved: (j['saved'] as num).toInt(),
    color: (j['color'] as num).toInt(),
  );

  SavingGoal copyWith({int? saved}) => SavingGoal(
    id: id,
    name: name,
    target: target,
    saved: saved ?? this.saved,
    color: color,
  );
}

const _goalsKey = 'duitqu.goals';

/// Penyimpanan lokal tujuan nabung.
class GoalsStore {
  Future<List<SavingGoal>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_goalsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => SavingGoal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _write(List<SavingGoal> goals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _goalsKey,
      jsonEncode(goals.map((g) => g.toJson()).toList()),
    );
  }

  Future<void> add(SavingGoal goal) async {
    final goals = await list();
    goals.add(goal);
    await _write(goals);
  }

  Future<void> addFunds(String id, int amount) async {
    final goals = await list();
    final i = goals.indexWhere((g) => g.id == id);
    if (i < 0) return;
    goals[i] = goals[i].copyWith(saved: goals[i].saved + amount);
    await _write(goals);
  }

  Future<void> remove(String id) async {
    final goals = await list();
    goals.removeWhere((g) => g.id == id);
    await _write(goals);
  }
}
