import 'dart:io';
import 'dart:convert';
import 'dart:async';

Future<void> main() async {
  final licenseKey = 'LIC-JQEL-CG2V-2ECX';
  final collectionId = '${licenseKey}_invoices';
  final baseUrl = 'https://firestore.googleapis.com/v1/projects/control-panel-add47/databases/(default)/documents/$collectionId';
  
  print('Fetching all invoices to repair dates...');
  
  final client = HttpClient();
  int fixedCount = 0;
  int checkedCount = 0;
  String? nextPageToken;
  
  try {
    do {
      var urlStr = '$baseUrl?pageSize=300';
      if (nextPageToken != null) {
        urlStr += '&pageToken=$nextPageToken';
      }
      
      bool success = false;
      int retries = 3;
      Map<String, dynamic> data = {};
      
      while (!success && retries > 0) {
        try {
          final request = await client.getUrl(Uri.parse(urlStr));
          final response = await request.close();
          final body = await response.transform(utf8.decoder).join();
          data = jsonDecode(body);
          success = true;
        } catch (e) {
          retries--;
          print('Network error fetching page, retries left: $retries');
          if (retries == 0) throw e;
          await Future.delayed(Duration(seconds: 2));
        }
      }
      
      if (!data.containsKey('documents')) {
        print('No documents found or end of list.');
        break;
      }
      
      final documents = data['documents'] as List;
      checkedCount += documents.length;
      print('Checked $checkedCount invoices so far...');
      
      for (var doc in documents) {
        final createTimeStr = doc['createTime'] as String;
        final createTime = DateTime.parse(createTimeStr).toLocal();
        
        final fields = doc['fields'] as Map<String, dynamic>? ?? {};
        final timestampField = fields['timestamp']?['integerValue'] ?? fields['timestamp']?['doubleValue'] ?? '0';
        final timestamp = double.parse(timestampField.toString()).toInt();
        
        final savedDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        
        // If the date is exactly in August 2026 (the buggy period) or is totally off
        if (savedDate.year == 2026 && savedDate.month == 8) {
          // Check if createTime is significantly different
          if (createTime.month != 8 || createTime.year != 2026) {
            final docName = doc['name'] as String;
            final invoiceId = docName.split('/').last;
            
            final properTimestamp = createTime.millisecondsSinceEpoch.toString();
            final properDateTimeStr = "${createTime.day.toString().padLeft(2, '0')}/${createTime.month.toString().padLeft(2, '0')} ${createTime.hour.toString().padLeft(2, '0')}:${createTime.minute.toString().padLeft(2, '0')}";
            
            print('>> Repairing $invoiceId | Was: $savedDate -> Now: $createTime');
            
            final patchBody = {
              'fields': {
                'timestamp': {'integerValue': properTimestamp},
                'dateTime': {'stringValue': properDateTimeStr}
              }
            };
            
            bool patchSuccess = false;
            int patchRetries = 3;
            while (!patchSuccess && patchRetries > 0) {
              try {
                final patchUrl = Uri.parse('https://firestore.googleapis.com/v1/$docName?updateMask.fieldPaths=timestamp&updateMask.fieldPaths=dateTime');
                final patchReq = await client.patchUrl(patchUrl);
                patchReq.headers.contentType = ContentType.json;
                patchReq.write(jsonEncode(patchBody));
                final patchRes = await patchReq.close();
                if (patchRes.statusCode == 200) {
                  patchSuccess = true;
                  fixedCount++;
                } else {
                  patchRetries--;
                  print('Failed to update $invoiceId: ${patchRes.statusCode}');
                  await Future.delayed(Duration(seconds: 1));
                }
              } catch (e) {
                patchRetries--;
                await Future.delayed(Duration(seconds: 1));
              }
            }
          }
        }
      }
      
      nextPageToken = data['nextPageToken'];
    } while (nextPageToken != null);
    
    print('-----------------------------------------');
    print('Repair Complete! Checked $checkedCount invoices. Fixed $fixedCount invoices.');
    
  } catch (e) {
    print('Critical Error: $e');
  } finally {
    client.close();
  }
}
