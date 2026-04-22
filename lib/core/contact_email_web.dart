import 'dart:convert';

import 'dart:html' as html;

Future<bool> composeContactEmail({
  required String recipientEmail,
  required String name,
  required String phone,
  required String description,
}) async {
  try {
    if (recipientEmail.isEmpty || !recipientEmail.contains('@')) {
      html.window.console.error('Invalid email: $recipientEmail');
      return false;
    }

    const endpoint = 'https://demo.nitya.ai/send-mail';

    final request = await html.HttpRequest.request(
      endpoint,
      method: 'POST',
      sendData: jsonEncode({
        'name': name,
        'phone': phone,
        'description': description,
        'user_email': recipientEmail,
      }),
      requestHeaders: {
        'Content-Type': 'application/json',
      },
    );

    print("STATUS: ${request.status}");
    print("RESPONSE: ${request.responseText}");

    final status = request.status ?? 0;
    return status >= 200 && status < 300;
  } catch (error) {
    html.window.console.error('mail submit failed: $error');
    return false;
  }
}
