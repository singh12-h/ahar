import 'dart:io';
import 'dart:convert';

void main() async {
  final url = Uri.parse('https://firestore.googleapis.com/v1/projects/control-panel-add47/databases/(default)/documents/saas_data/central_db');
  final client = HttpClient();
  try {
    final request = await client.getUrl(url);
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    final Map<String, dynamic> data = jsonDecode(responseBody);
    final String dbJsonStr = data['fields']['dbJson']['stringValue'];
    
    // Pretty print and write to file
    final parsedJson = jsonDecode(dbJsonStr);
    final file = File('central_db_pretty.json');
    file.writeAsStringSync(JsonEncoder.withIndent('  ').convert(parsedJson));
    print('Fetched and saved central_db_pretty.json successfully. Size: ${file.lengthSync()} bytes');
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
