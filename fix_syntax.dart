import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    var content = file.readAsStringSync();
    
    // Fix the syntax error added by my previous bad regex script
    bool modified = false;
    if (content.contains("    ,\n    );")) {
       content = content.replaceAll("    ,\n    );", "    );");
       modified = true;
    }
    if (content.contains(",\n    );")) {
       content = content.replaceAll(",\n    );", "\n    );");
       modified = true;
    }
    
    // Fix targetMonth loops where `now.month - i` is used
    if (content.contains("var targetMonth = now.month - i;") || content.contains("var targetMonth = now.month - i;")) {
       content = content.replaceAll(
          "var targetMonth = now.month - i;",
          "final currentTarget = BudgetCycleHelper.getTargetMonthForDate(now, settings.budgetCycleMode, settings.budgetCycleStartDay);\n      var targetMonth = currentTarget.month - i;"
       );
       content = content.replaceAll(
          "var targetYear = now.year;",
          "var targetYear = currentTarget.year;"
       );
       modified = true;
    }

    if (modified) {
      file.writeAsStringSync(content);
      print("Updated ${file.path}");
    }
  }
}
