import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailService {
  static Future<void> sendApprovalEmail({
    required String name,
    required String email,
    required String employeeId,
  }) async {
    const serviceId = "service_4k56j7i";
    const templateId = "template_2l5oq7i";
    const publicKey = "VdaQL1byB98jufD1-";

    final url = Uri.parse("https://api.emailjs.com/api/v1.0/email/send");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "origin": "http://localhost",
      },
      body: jsonEncode({
        "service_id": serviceId,
        "template_id": templateId,
        "user_id": publicKey,
        "template_params": {
          "name": name,
          "email": email,
          "employeeId": employeeId,
          "password": "123456",
        }
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to send approval email");
    }
  }
}
