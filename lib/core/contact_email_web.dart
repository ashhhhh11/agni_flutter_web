import 'dart:convert';
import 'dart:html' as html;

Future<bool> composeContactEmail({
  required String recipientEmail,
  required String name,
  required String phone,
  required String senderEmail,
}) async {
  try {
    final endpoint = 'https://formsubmit.co/ajax/$recipientEmail';
    final payload = <String, dynamic>{
      'name': name,
      'phone': phone,
      'email': senderEmail,
      '_subject': 'New contact request',
      'message': 'Hello all,\nA new contact request was submitted.',
    };

    final response = await html.HttpRequest.request(
      endpoint,
      method: 'POST',
      sendData: jsonEncode(payload),
      requestHeaders: <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    return response.status == 200;
  } catch (_) {
    return false;
  }
}
