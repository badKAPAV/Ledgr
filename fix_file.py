import re

with open('lib/features/transaction/widgets/transaction_details_screen/transaction_detail_screen.dart', 'r') as f:
    content = f.read()

# Add imports
imports = """
import 'package:wallzy/features/transaction/widgets/transaction_details_screen/slim_info_row.dart';
import 'package:wallzy/features/transaction/widgets/transaction_details_screen/action_tile.dart';
import 'package:wallzy/features/transaction/widgets/transaction_details_screen/status_badge.dart';
import 'package:wallzy/features/transaction/widgets/transaction_details_screen/action_box.dart';
"""
content = re.sub(r"(import 'package:wallzy/features/categories/provider/category_provider.dart';)", r"\1\n" + imports.strip() + "\n", content)

# Replace class usages in the wild (we only want to replace instances, but since we will delete the class definitions next, we can just blind replace all)
content = content.replace('_SlimInfoRow', 'SlimInfoRow')
content = content.replace('_ActionTile', 'ActionTile')
content = content.replace('_StatusBadge', 'StatusBadge')

# Delete everything below `// --- NEW UI COMPONENTS ---`
index = content.find('// --- NEW UI COMPONENTS ---')
if index != -1:
    content = content[:index]

with open('lib/features/transaction/widgets/transaction_details_screen/transaction_detail_screen.dart', 'w') as f:
    f.write(content)
