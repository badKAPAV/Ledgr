import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallzy/core/utils/budget_cycle_helper.dart';

class SettingsProvider with ChangeNotifier {
  bool _autoRecordTransactions = false;

  BudgetCycleMode _budgetCycleMode = BudgetCycleMode.defaultMonth;
  int _budgetCycleStartDay = 1;

  // Currency Settings
  String _currencyCode = 'INR';
  String _currencySymbol = '₹';
  String _currencyIsoCodeNum = '356'; // India ISO Num
  bool _isSettingsLoaded = false;

  bool get autoRecordTransactions => _autoRecordTransactions;
  BudgetCycleMode get budgetCycleMode => _budgetCycleMode;
  int get budgetCycleStartDay => _budgetCycleStartDay;

  String get currencyCode => _currencyCode;
  String get currencySymbol => _currencySymbol;
  String get currencyIsoCodeNum => _currencyIsoCodeNum;
  bool get isSettingsLoaded => _isSettingsLoaded;

  // Notification Settings
  bool _enableMonthlyLimitAlert = false;
  bool _enableDailyLimitAlert = false;
  bool _enableDailySummary = false;
  bool _enableWeeklySummary = false;
  bool _enableMonthlySummary = false;
  String? _lastDailyAlertDate;
  String? _lastMonthlyAlertMonth;

  bool get enableMonthlyLimitAlert => _enableMonthlyLimitAlert;
  bool get enableDailyLimitAlert => _enableDailyLimitAlert;
  bool get enableDailySummary => _enableDailySummary;
  bool get enableWeeklySummary => _enableWeeklySummary;
  bool get enableMonthlySummary => _enableMonthlySummary;
  String? get lastDailyAlertDate => _lastDailyAlertDate;
  String? get lastMonthlyAlertMonth => _lastMonthlyAlertMonth;

  // Debug Notification Settings
  String? _dailyDebugTime;
  String? _weeklyDebugTime;
  String? _monthlyDebugTime;

  String? get dailyDebugTime => _dailyDebugTime;
  String? get weeklyDebugTime => _weeklyDebugTime;
  String? get monthlyDebugTime => _monthlyDebugTime;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoRecordTransactions =
        prefs.getBool('auto_record_transactions') ?? false;

    // Load Budget Cycle Settings
    final modeIndex = prefs.getInt('budget_cycle_mode') ?? 0;
    _budgetCycleMode = BudgetCycleMode.values[modeIndex];
    _budgetCycleStartDay = prefs.getInt('budget_cycle_start_day') ?? 1;

    // Load Currency Settings
    _currencyCode = prefs.getString('currency_code') ?? 'INR';
    _currencySymbol = prefs.getString('currency_symbol') ?? '₹';
    _currencyIsoCodeNum = prefs.getString('currency_iso_code_num') ?? '356';

    // Load Notification Settings
    _enableMonthlyLimitAlert = prefs.getBool('enable_monthly_limit_alert') ?? false;
    _enableDailyLimitAlert = prefs.getBool('enable_daily_limit_alert') ?? false;
    _enableDailySummary = prefs.getBool('enable_daily_summary') ?? false;
    _enableWeeklySummary = prefs.getBool('enable_weekly_summary') ?? false;
    _enableMonthlySummary = prefs.getBool('enable_monthly_summary') ?? false;
    _lastDailyAlertDate = prefs.getString('last_daily_alert_date');
    _lastMonthlyAlertMonth = prefs.getString('last_monthly_alert_month');

    // Load Debug Times
    _dailyDebugTime = prefs.getString('daily_debug_time');
    _weeklyDebugTime = prefs.getString('weekly_debug_time');
    _monthlyDebugTime = prefs.getString('monthly_debug_time');

    _isSettingsLoaded = true;
    notifyListeners();
  }

  Future<void> setAutoRecordTransactions(bool value) async {
    if (_autoRecordTransactions == value) return;
    _autoRecordTransactions = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_record_transactions', value);
  }

  Future<void> setBudgetCycleMode(BudgetCycleMode mode) async {
    if (_budgetCycleMode == mode) return;
    _budgetCycleMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('budget_cycle_mode', mode.index);
  }

  Future<void> setBudgetCycleStartDay(int day) async {
    if (_budgetCycleStartDay == day) return;
    _budgetCycleStartDay = day;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('budget_cycle_start_day', day);
  }

  Future<void> setCurrency(
    String code,
    String symbol,
    String isoCodeNum,
  ) async {
    if (_currencyCode == code &&
        _currencySymbol == symbol &&
        _currencyIsoCodeNum == isoCodeNum)
      return;
    _currencyCode = code;
    _currencySymbol = symbol;
    _currencyIsoCodeNum = isoCodeNum;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency_code', code);
    await prefs.setString('currency_symbol', symbol);
    await prefs.setString('currency_iso_code_num', isoCodeNum);
  }

  // --- OFFLINE MODE STATE ---
  bool _isOffline = false;
  bool get isOffline => _isOffline;

  void setOfflineStatus(bool value) {
    if (_isOffline == value) return;
    _isOffline = value;
    notifyListeners();
  }

  // Notification Setters
  Future<void> setEnableMonthlyLimitAlert(bool value) async {
    if (_enableMonthlyLimitAlert == value) return;
    _enableMonthlyLimitAlert = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_monthly_limit_alert', value);
  }

  Future<void> setEnableDailyLimitAlert(bool value) async {
    if (_enableDailyLimitAlert == value) return;
    _enableDailyLimitAlert = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_daily_limit_alert', value);
  }

  Future<void> setEnableDailySummary(bool value) async {
    if (_enableDailySummary == value) return;
    _enableDailySummary = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_daily_summary', value);
  }

  Future<void> setEnableWeeklySummary(bool value) async {
    if (_enableWeeklySummary == value) return;
    _enableWeeklySummary = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_weekly_summary', value);
  }

  Future<void> setEnableMonthlySummary(bool value) async {
    if (_enableMonthlySummary == value) return;
    _enableMonthlySummary = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_monthly_summary', value);
  }

  Future<void> setLastDailyAlertDate(String date) async {
    _lastDailyAlertDate = date;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_daily_alert_date', date);
  }

  Future<void> setLastMonthlyAlertMonth(String month) async {
    _lastMonthlyAlertMonth = month;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_monthly_alert_month', month);
  }

  // Debug Notification Setters
  Future<void> setDailyDebugTime(String? time) async {
    _dailyDebugTime = time;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (time == null) {
      await prefs.remove('daily_debug_time');
    } else {
      await prefs.setString('daily_debug_time', time);
    }
  }

  Future<void> setWeeklyDebugTime(String? time) async {
    _weeklyDebugTime = time;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (time == null) {
      await prefs.remove('weekly_debug_time');
    } else {
      await prefs.setString('weekly_debug_time', time);
    }
  }

  Future<void> setMonthlyDebugTime(String? time) async {
    _monthlyDebugTime = time;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (time == null) {
      await prefs.remove('monthly_debug_time');
    } else {
      await prefs.setString('monthly_debug_time', time);
    }
  }
}
