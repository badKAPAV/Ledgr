import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    if (file.path.contains('budget_cycle_helper.dart')) continue;

    var content = file.readAsStringSync();
    if (!content.contains('BudgetCycleHelper.getCycleRange')) continue;

    bool modified = false;

    // Pattern for DateTime.now()
    var patternNow = RegExp(r"BudgetCycleHelper\.getCycleRange\(\s*targetMonth:\s*DateTime\.now\(\)\.month,\s*targetYear:\s*DateTime\.now\(\)\.year,\s*mode:\s*([^,]+),\s*startDay:\s*([^\)]+),?\s*\)");
    
    if (patternNow.hasMatch(content)) {
      content = content.replaceAllMapped(patternNow, (m) {
        return "BudgetCycleHelper.currentCycleRange(\n      DateTime.now(),\n      ${m.group(1)},\n      ${m.group(2)},\n    )";
      });
      modified = true;
    }

    // Identify and replace 'now.month' when it's passed directly 
    // Usually it looks like:
    // targetMonth: now.month,
    // targetYear: now.year,
    var patternNowVar = RegExp(r"BudgetCycleHelper\.getCycleRange\(\s*targetMonth:\s*now\.month,\s*targetYear:\s*now\.year,\s*mode:\s*([^,]+),\s*startDay:\s*([^\)]+),?\s*\)");
    
    if (patternNowVar.hasMatch(content)) {
      content = content.replaceAllMapped(patternNowVar, (m) {
        return "BudgetCycleHelper.currentCycleRange(\n      now,\n      ${m.group(1)},\n      ${m.group(2)},\n    )";
      });
      modified = true;
    }

    // Find other occurrences in the file and print them to investigate
    if (content.contains('targetMonth')) {
       print("Check file manually: ${file.path}");
    }

    if (modified) {
      file.writeAsStringSync(content);
      print("Updated ${file.path}");
    }
  }
}
