import 'dart:io';
import 'dart:convert';

void main() async {
  final licenseKey = 'LIC-JQEL-CG2V-2ECX';
  final invoiceId = 'INV-9816';
  final urlStr = 'https://firestore.googleapis.com/v1/projects/control-panel-add47/databases/(default)/documents/${licenseKey}_invoices/$invoiceId';
  
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(urlStr));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    
    print('Result for $invoiceId:');
    print(body);
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
