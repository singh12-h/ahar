import 'dart:io';

void main() {
  final file = File('c:/Project/ahar_flutter/lib/app_state.dart');
  var content = file.readAsStringSync();

  // 1. Add import for default_menu_data.dart
  if (!content.contains("import 'default_menu_data.dart';")) {
    content = content.replaceFirst(
      "import 'tenant_db_manager.dart';",
      "import 'tenant_db_manager.dart';\nimport 'default_menu_data.dart';"
    );
  }

  // 2. Replace defaultCategories
  final catRegex = RegExp(r'final List<CategoryModel> defaultCategories = \[.*?\];', dotAll: true);
  if (catRegex.hasMatch(content)) {
    content = content.replaceFirst(catRegex, 'final List<CategoryModel> defaultCategories = newDefaultCategories;');
  }

  // 3. Replace defaultMenu
  final menuRegex = RegExp(r'final List<MenuItem> defaultMenu = \[.*?\];', dotAll: true);
  if (menuRegex.hasMatch(content)) {
    content = content.replaceFirst(menuRegex, 'final List<MenuItem> defaultMenu = newDefaultMenu;');
  }

  // 4. Bump currentMenuVersion
  content = content.replaceAll("'v14'", "'v15'");

  // 5. Replace currentMenuVersion assignment
  final verRegex = RegExp(r"final currentMenuVersion = 'v14';");
  if (verRegex.hasMatch(content)) {
      content = content.replaceFirst(verRegex, "final currentMenuVersion = 'v15';");
  }

  file.writeAsStringSync(content);
  print('Successfully updated app_state.dart');
}
