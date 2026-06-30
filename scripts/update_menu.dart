import 'dart:io';

String normalize(String s) {
  return s
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll('.', '')
      .replaceAll('(', '')
      .replaceAll(')', '')
      .replaceAll("'", '')
      .replaceAll('"', '')
      .replaceAll('-', '')
      .toLowerCase();
}

void main() {
  final appStateFile = File('lib/app_state.dart');
  final menuDataFile = File('lib/default_menu_data.dart');

  if (!appStateFile.existsSync() || !menuDataFile.existsSync()) {
    print('Error: Could not find lib/app_state.dart or lib/default_menu_data.dart. Run from project root.');
    exit(1);
  }

  final appStateContent = appStateFile.readAsStringSync();
  final menuDataContent = menuDataFile.readAsStringSync();

  // Find ignoredOldMenu in app_state.dart
  final ignoredOldMenuStartIndex = appStateContent.indexOf('final List<MenuItem> ignoredOldMenu = [');
  if (ignoredOldMenuStartIndex == -1) {
    print('Error: Could not find ignoredOldMenu in app_state.dart');
    exit(1);
  }
  
  // Find matching closing bracket for ignoredOldMenu
  int bracketCount = 1;
  int currentIndex = appStateContent.indexOf('[', ignoredOldMenuStartIndex) + 1;
  while (bracketCount > 0 && currentIndex < appStateContent.length) {
    if (appStateContent[currentIndex] == '[') {
      bracketCount++;
    } else if (appStateContent[currentIndex] == ']') {
      bracketCount--;
    }
    currentIndex++;
  }
  final ignoredOldMenuBlock = appStateContent.substring(ignoredOldMenuStartIndex, currentIndex);

  // Parse items from ignoredOldMenuBlock
  // Regex to match: MenuItem(id: <id>, name: "<name>", price: <price>
  final itemRegex = RegExp(r'MenuItem\(\s*id:\s*(\d+),\s*name:\s*"([^"]+)",\s*price:\s*(\d+)');
  final Map<String, int> oldRates = {};
  final Map<String, String> oldNames = {};

  for (final match in itemRegex.allMatches(ignoredOldMenuBlock)) {
    final name = match.group(2)!;
    final price = int.parse(match.group(3)!);
    final norm = normalize(name);
    oldRates[norm] = price;
    oldNames[norm] = name;
  }

  print('Parsed ${oldRates.length} items from ignoredOldMenu in app_state.dart');

  // Process lib/default_menu_data.dart line by line
  final lines = menuDataContent.split('\n');
  int updatedCount = 0;
  final List<String> updatedLines = [];

  for (var line in lines) {
    if (line.contains('MenuItem(')) {
      final match = itemRegex.firstMatch(line);
      if (match != null) {
        final id = match.group(1)!;
        final name = match.group(2)!;
        final price = int.parse(match.group(3)!);
        final norm = normalize(name);

        if (oldRates.containsKey(norm)) {
          final newPrice = oldRates[norm]!;
          if (price != newPrice) {
            // Replace the price in the line
            final updatedLine = line.replaceFirst('price: $price', 'price: $newPrice');
            updatedLines.add(updatedLine);
            print('Updated: "$name" (ID: $id) price $price -> $newPrice');
            updatedCount++;
            continue;
          }
        } else {
          print('Warning: No match in old menu for "$name" (ID: $id)');
        }
      }
    }
    updatedLines.add(line);
  }

  // Write updated menu data back
  menuDataFile.writeAsStringSync(updatedLines.join('\n'));
  print('Successfully updated $updatedCount prices in lib/default_menu_data.dart');

  // Bump menu version in app_state.dart
  var updatedAppState = appStateContent;
  
  // Replace currentMenuVersion = 'v12' with 'v13'
  final versionRegex = RegExp(r"final currentMenuVersion = 'v12';");
  if (versionRegex.hasMatch(updatedAppState)) {
    updatedAppState = updatedAppState.replaceFirst(versionRegex, "final currentMenuVersion = 'v13';");
    print('Bumped currentMenuVersion in app_state.dart to v13');
  } else {
    print('Warning: currentMenuVersion = \'v12\' not found in app_state.dart');
  }

  appStateFile.writeAsStringSync(updatedAppState);
  print('Menu sync completed.');
}
