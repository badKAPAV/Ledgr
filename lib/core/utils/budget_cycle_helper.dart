import 'package:flutter/material.dart';

enum BudgetCycleMode {
  defaultMonth, // 1st to End of Month
  customDate, // e.g., 25th to 24th
  lastDay, // Last day of prev month to 2nd-to-last of current
}

class BudgetCycleHelper {
  /// Returns the start and end dates for a given 'budget month'.
  ///
  /// [targetMonth] and [targetYear] refer to the "Label" month.
  /// E.g., if the user wants "April 2024" stats:
  /// - Default: Apr 1 - Apr 30
  /// - Custom (25th): Mar 25 - Apr 24
  /// - Last Day: Mar 31 - Apr 29
  static DateTimeRange getCycleRange({
    required int targetMonth,
    required int targetYear,
    required BudgetCycleMode mode,
    int startDay = 1,
  }) {
    DateTime start;
    DateTime end;

    switch (mode) {
      case BudgetCycleMode.defaultMonth:
        // Standard Calendar Month: 1st 00:00 to NextMonth 1st 00:00 (exclusive)
        start = DateTime(targetYear, targetMonth, 1);
        final nextMonth = DateTime(targetYear, targetMonth + 1, 1);
        end = nextMonth.subtract(
          const Duration(milliseconds: 1),
        ); // End of last day
        // For range logic using filter where end is exclusive, we usually return
        // the exact start of the next period.
        // Adapting to existing app logic which seems to use [start, end_inclusive] or [start, end_exclusive].
        // Looking at home_screen.dart: `end: now.add(const Duration(days: 1))` suggests exclusive upper bound logic for days.
        // Let's return strict boundaries: Start of first day, and strict Start of next cycle's first day.
        // Making it inclusive by subtracting 1 microsecond.
        end = nextMonth.subtract(const Duration(microseconds: 1));
        break;

      case BudgetCycleMode.customDate:
        // Cycle starts on [startDay] of current month.
        // E.g. Target November, StartDay 7.
        // Range: November 7 - December 6 (End is December 7th 00:00 exclusive)

        // Start date is [startDay] of current target month.
        final actualStartDate = _resolveValidDate(
          targetYear,
          targetMonth,
          startDay,
        );
        start = DateTime(targetYear, targetMonth, actualStartDate);

        // Calculate "Next Month"
        int nextMonthYear = targetYear;
        int nextMonth = targetMonth + 1;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextMonthYear++;
        }

        // End date is [startDay] of next month, minus 1 microsecond to be inclusive.
        final actualEndDateDay = _resolveValidDate(
          nextMonthYear,
          nextMonth,
          startDay,
        );
        end = DateTime(nextMonthYear, nextMonth, actualEndDateDay)
            .subtract(const Duration(microseconds: 1));
        break;

      case BudgetCycleMode.lastDay:
        // Cycle starts on the last day of the previous month.
        // E.g. Target April. prevMonth = March. Last day is Mar 31.
        // Cycle: Mar 31 - Apr 29 (End is Apr 30 00:00 exclusive).

        // "Previous Month"
        final prevMonthDate = DateTime(
          targetYear,
          targetMonth - 1,
          1,
        ); // e.g. March 1
        final lastDayPrevMonth = DateTime(
          prevMonthDate.year,
          prevMonthDate.month + 1,
          0,
        ); // Mar 31

        start = DateTime(
          lastDayPrevMonth.year,
          lastDayPrevMonth.month,
          lastDayPrevMonth.day,
        );

        // End date is the last day of the target month minus 1 microsecond.
        // "Last Day Mode: Starts on the last day of the *previous* month."
        // Meaning the cycle for April starts Mar 31.
        // The cycle for May would start Apr 30.
        // So the April cycle ends on Apr 29.
        final targetMonthDate = DateTime(targetYear, targetMonth, 1);
        final lastDayTargetMonth = DateTime(
          targetMonthDate.year,
          targetMonthDate.month + 1,
          0,
        ); // Apr 30

        end = DateTime(
          lastDayTargetMonth.year,
          lastDayTargetMonth.month,
          lastDayTargetMonth.day,
        ).subtract(const Duration(microseconds: 1));
        break;
    }

    return DateTimeRange(start: start, end: end);
  }

  /// Helper: Returns a day that is valid for the given month/year.
  /// If [day] is 31 but month only has 30, returns 30.
  static int _resolveValidDate(int year, int month, int day) {
    // Get last day of this month
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    return day > lastDayOfMonth ? lastDayOfMonth : day;
  }

  /// Determines the logical "target month/year" that the given [date] falls into.
  /// Useful for figuring out "This Month's" cycle dynamically.
  static DateTime getTargetMonthForDate(
    DateTime date,
    BudgetCycleMode mode,
    int startDay,
  ) {
    int targetMonth = date.month;
    int targetYear = date.year;

    if (mode == BudgetCycleMode.customDate) {
      if (date.day < startDay) {
        targetMonth--;
        if (targetMonth == 0) {
          targetMonth = 12;
          targetYear--;
        }
      }
    } else if (mode == BudgetCycleMode.lastDay) {
      final lastDayOfMonth = DateTime(date.year, date.month + 1, 0).day;
      if (date.day == lastDayOfMonth) {
        targetMonth++;
        if (targetMonth > 12) {
          targetMonth = 1;
          targetYear++;
        }
      }
    }
    return DateTime(targetYear, targetMonth, 1);
  }

  /// Returns the budget cycle range that directly contains the given [date].
  static DateTimeRange currentCycleRange(
    DateTime date,
    BudgetCycleMode mode,
    int startDay,
  ) {
    final target = getTargetMonthForDate(date, mode, startDay);
    return getCycleRange(
      targetMonth: target.month,
      targetYear: target.year,
      mode: mode,
      startDay: startDay
    );
  }
}
