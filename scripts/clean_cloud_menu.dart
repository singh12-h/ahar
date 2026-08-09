import 'dart:io';
import 'dart:convert';

const projectId = 'ahar-77377';
const licenseKey = 'LIC-JQEL-CG2V-2ECX';

void main() async {
  final client = HttpClient();
  print('Starting manual database cleanup on cloud...');

  try {
    // 1. Clean Menu Items
    await deleteCollection(client, '${licenseKey}_menu_items');
    
    // 2. Clean Categories
    await deleteCollection(client, '${licenseKey}_categories');

    print('\nCleanup complete! Now run/reload your app to sync the fresh menu items.');
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}

Future<void> deleteCollection(HttpClient client, String collectionId) async {
  print('\nWiping collection: $collectionId');
  final listUrl = Uri.parse('https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$collectionId?pageSize=300');
  
  final request = await client.getUrl(listUrl);
  final response = await request.close();
  if (response.statusCode == 404) {
    print('Collection $collectionId does not exist or is already empty.');
    return;
  }
  
  final responseBody = await response.transform(utf8.decoder).join();
  final Map<String, dynamic> data = jsonDecode(responseBody);
  
  final List? documents = data['documents'];
  if (documents == null || documents.isEmpty) {
    print('No documents found in $collectionId.');
    return;
  }
  
  print('Found ${documents.length} documents. Deleting...');
  for (var doc in documents) {
    final String docPath = doc['name'];
    final deleteUrl = Uri.parse('https://firestore.googleapis.com/v1/$docPath');
    final deleteReq = await client.deleteUrl(deleteUrl);
    final deleteRes = await deleteReq.close();
    if (deleteRes.statusCode == 200) {
      print('Deleted: ${docPath.split('/').last}');
    } else {
      print('Failed to delete ${docPath.split('/').last}: ${deleteRes.statusCode}');
    }
  }
}
