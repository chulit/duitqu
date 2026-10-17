import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Kategori tujuan predefinisi (dari mockup).
enum GoalCategory {
  rumah('Home', 'assets/icons/goals/home.webp', 0xFFF2994A),
  laptop('Electronic', 'assets/icons/goals/electronic.webp', 0xFF9B51E0),
  liburan('Vacation', 'assets/icons/goals/vacation.webp', 0xFF2E9BFF),
  mobil('Vehicle', 'assets/icons/goals/vehicle.webp', 0xFF2D9CDB),
  pendidikan('Education', 'assets/icons/goals/study.webp', 0xFF27AE60),
  barangImpian('Wishlist', 'assets/icons/goals/wishlist.webp', 0xFFEB5757),
  danaDarurat('Emergency Fund', 'assets/icons/goals/emergency_fund.webp', 0xFFF2C94C),
  lainnya('Other', 'assets/icons/goals/other.webp', 0xFFBDBDBD);

  final String label;
  final String iconAsset;
  final int color;

  const GoalCategory(this.label, this.iconAsset, this.color);
}

/// Model tujuan nabung.
class SavingGoal {
  final String id;
  final String name;
  final int target;
  final int saved;
  final GoalCategory category;
  final DateTime? deadline;
  final String? note;
  /// Riwayat kontribusi: tanggal -> nominal (untuk chart Perkembangan).
  final List<GoalContribution> contributions;

  const SavingGoal({
    required this.id,
    required this.name,
    required this.target,
    required this.saved,
    required this.category,
    this.deadline,
    this.note,
    this.contributions = const [],
  });

  int get color => category.color;
  double get progress => target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0);
  bool get isCompleted => saved >= target && target > 0;
  bool get isExpired {
    if (deadline == null || isCompleted) return false;
    final now = DateTime.now();
    final d = DateTime(deadline!.year, deadline!.month, deadline!.day);
    final n = DateTime(now.year, now.month, now.day);
    return d.isBefore(n);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'target': target,
    'saved': saved,
    'category': category.name,
    'deadline': deadline?.toIso8601String(),
    'note': note,
    'contributions': contributions.map((c) => c.toJson()).toList(),
    // Kompatibel dengan format lama.
    'color': color,
  };

  factory SavingGoal.fromJson(Map<String, dynamic> j) {
    final catName = j['category'] as String?;
    final category = catName == null
        ? GoalCategory.lainnya
        : GoalCategory.values.firstWhere(
            (c) => c.name == catName,
            orElse: () => GoalCategory.lainnya,
          );
    return SavingGoal(
      id: j['id'] as String,
      name: j['name'] as String,
      target: (j['target'] as num).toInt(),
      saved: (j['saved'] as num).toInt(),
      category: category,
      deadline: j['deadline'] == null
          ? null
          : DateTime.parse(j['deadline'] as String),
      note: j['note'] as String?,
      contributions: (j['contributions'] as List? ?? [])
          .map((e) => GoalContribution.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  SavingGoal copyWith({
    int? saved,
    int? target,
    DateTime? deadline,
    String? note,
    List<GoalContribution>? contributions,
  }) =>
      SavingGoal(
        id: id,
        name: name,
        target: target ?? this.target,
        saved: saved ?? this.saved,
        category: category,
        deadline: deadline ?? this.deadline,
        note: note ?? this.note,
        contributions: contributions ?? this.contributions,
      );
}

/// Satu kontribusi tabungan.
class GoalContribution {
  final DateTime date;
  final int amount;
  final String? source; // "Transfer", "Tabungan", dst.

  const GoalContribution({
    required this.date,
    required this.amount,
    this.source,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'amount': amount,
    'source': source,
  };

  factory GoalContribution.fromJson(Map<String, dynamic> j) =>
      GoalContribution(
        date: DateTime.parse(j['date'] as String),
        amount: (j['amount'] as num).toInt(),
        source: j['source'] as String?,
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

  Future<void> addFunds(String id, int amount, {String? source}) async {
    final goals = await list();
    final i = goals.indexWhere((g) => g.id == id);
    if (i < 0) return;
    final g = goals[i];
    goals[i] = g.copyWith(
      saved: g.saved + amount,
      contributions: [
        ...g.contributions,
        GoalContribution(
          date: DateTime.now(),
          amount: amount,
          source: source,
        ),
      ],
    );
    await _write(goals);
  }

  Future<void> update(SavingGoal goal) async {
    final goals = await list();
    final i = goals.indexWhere((g) => g.id == goal.id);
    if (i < 0) return;
    goals[i] = goal;
    await _write(goals);
  }

  Future<void> remove(String id) async {
    final goals = await list();
    goals.removeWhere((g) => g.id == id);
    await _write(goals);
  }
}
