import 'package:flutter/material.dart';

import '../domain/entities/account.dart';

/// Mapping nama ikon kategori (disimpan sebagai string di DB, gaya Lucide)
/// ke [IconData] Material. Kategori kustom tanpa nama yang dikenal
/// jatuh ke [Icons.category].
IconData categoryIcon(String? name) {
  switch (name) {
    case 'utensils':
      return Icons.restaurant_rounded;
    case 'car':
      return Icons.directions_car_rounded;
    case 'shopping-bag':
      return Icons.shopping_bag_rounded;
    case 'receipt':
      return Icons.receipt_long_rounded;
    case 'smartphone':
      return Icons.smartphone_rounded;
    case 'heart-pulse':
      return Icons.favorite_rounded;
    case 'clapperboard':
      return Icons.movie_rounded;
    case 'graduation-cap':
      return Icons.school_rounded;
    case 'briefcase':
      return Icons.work_rounded;
    case 'gift':
      return Icons.card_giftcard_rounded;
    case 'landmark':
      return Icons.account_balance_rounded;
    case 'shapes':
      return Icons.category_rounded;
    default:
      return Icons.category_rounded;
  }
}

/// Ikon untuk jenis akun.
IconData accountIcon(AccountType type) {
  switch (type) {
    case AccountType.bank:
      return Icons.account_balance_rounded;
    case AccountType.cash:
      return Icons.wallet_rounded;
    case AccountType.ewallet:
      return Icons.smartphone_rounded;
    case AccountType.other:
      return Icons.account_box_rounded;
  }
}
