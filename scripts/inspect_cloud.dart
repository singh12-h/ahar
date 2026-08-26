import 'dart:io';
import 'dart:convert';

void main() async {
  final licenseKey = 'LIC-JQEL-CG2V-2ECX';
  final urlStr = 'https://firestore.googleapis.com/v1/projects/control-panel-add47/databases/(default)/documents/${licenseKey}_invoices';
  final client = HttpClient();
  
  try {
    String? nextPageToken;
    int count = 0;
    print('Fetching all Invoice IDs from Cloud...');
    
    do {
      var url = urlStr;
      if (nextPageToken != null) {
        url += '?pageToken=$nextPageToken';
      }
      
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      
      if (data['documents'] != null) {
        for (var doc in data['documents']) {
          final docName = doc['name'] as String;
          final id = docName.split('/').last;
          if (id.contains('999') || id.contains('627') || id.contains('956')) {
             print('Found matching ID in cloud: $id');
          }
          count++;
        }
      }
      
      nextPageToken = data['nextPageToken'];
    } while (nextPageToken != null);
    
    print('Total invoices in Cloud for this License Key: $count');
    
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
