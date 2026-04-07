import 'package:shared_preferences/shared_preferences.dart';

/// Demo wallet used only in Demo mode (no real payments).
///
/// Keeps a persistent INR balance in local storage so it decreases with each
/// demo purchase, matching "₹5000 to invest" behavior.
class DemoWalletService {
  static const int initialBalanceInr = 5000;
  static const String _balanceKey = 'artyug_demo_wallet_balance_inr_v1';

  static Future<int> getBalanceInr() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getInt(_balanceKey);
    if (existing != null) return existing;
    await prefs.setInt(_balanceKey, initialBalanceInr);
    return initialBalanceInr;
  }

  /// Attempts to spend [amountInr]. Returns true if successful.
  static Future<bool> trySpendInr(int amountInr) async {
    if (amountInr <= 0) return true;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_balanceKey) ?? initialBalanceInr;
    if (current < amountInr) return false;
    await prefs.setInt(_balanceKey, current - amountInr);
    return true;
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_balanceKey, initialBalanceInr);
  }
}

