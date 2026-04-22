import 'package:wallzy/features/transaction/widgets/add_edit_transaction_widgets/transaction_widgets.dart';

enum CategoryType { defaultType, customType }

class CategoryModel {
  final String id;
  final String name;
  final CategoryType type;
  final TransactionMode mode;
  final String iconKey;
  final List<String> keywords;
  final double? budget;
  final bool isDeleted;
  final bool isDefault;

  CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.mode,
    required this.iconKey,
    required this.keywords,
    required this.budget,
    required this.isDeleted,
    required this.isDefault,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'],
      name: map['name'],
      type: CategoryType.values.firstWhere((e) => e.name == map['type']),
      mode: TransactionMode.values.firstWhere((e) => e.name == map['mode']),
      iconKey: map['iconKey'],
      keywords: List<String>.from(map['keywords']),
      budget: map['budget'],
      isDeleted: map['isDeleted'],
      isDefault: map['isDefault'] ?? false
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'mode': mode.name,
      'iconKey': iconKey,
      'keywords': keywords,
      'budget': budget,
      'isDeleted': isDeleted,
      'isDefault': isDefault,
    };
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    CategoryType? type,
    TransactionMode? mode,
    String? iconKey,
    List<String>? keywords,
    double? budget,
    bool? isDeleted,
    bool? isDefault,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      mode: mode ?? this.mode,
      iconKey: iconKey ?? this.iconKey,
      keywords: keywords ?? this.keywords,
      budget: budget ?? this.budget,
      isDeleted: isDeleted ?? this.isDeleted,
      isDefault: isDefault ?? this.isDefault
    );
  }
}
