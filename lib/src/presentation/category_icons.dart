import 'package:flutter/material.dart';

import '../domain/entities/account.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Mapping nama ikon kategori (disimpan sebagai string di DB, gaya Lucide)
/// ke [IconData] Material. Kategori kustom tanpa nama yang dikenal
/// jatuh ke [LucideIcons.layoutGrid].
IconData categoryIcon(String? name) {
  switch (name) {
    case 'utensils':
      return LucideIcons.utensils;
    case 'car':
      return LucideIcons.car;
    case 'shopping-bag':
      return LucideIcons.shoppingBag;
    case 'receipt':
      return LucideIcons.receipt;
    case 'smartphone':
      return LucideIcons.smartphone;
    case 'heart-pulse':
      return LucideIcons.heart;
    case 'clapperboard':
      return LucideIcons.clapperboard;
    case 'graduation-cap':
      return LucideIcons.graduationCap;
    case 'briefcase':
      return LucideIcons.briefcase;
    case 'gift':
      return LucideIcons.gift;
    case 'landmark':
      return LucideIcons.landmark;
    case 'shapes':
      return LucideIcons.layoutGrid;
    default:
      return LucideIcons.layoutGrid;
  }
}

/// Ikon untuk jenis akun.
IconData accountIcon(AccountType type) {
  switch (type) {
    case AccountType.bank:
      return LucideIcons.landmark;
    case AccountType.cash:
      return LucideIcons.wallet;
    case AccountType.ewallet:
      return LucideIcons.smartphone;
    case AccountType.other:
      return LucideIcons.contact;
  }
}
