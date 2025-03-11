import 'package:http/http.dart' as http;
import 'dart:convert';

class RequestHelper {
  static Future<dynamic> getRequest(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        String data = response.body;
        var decodedData = jsonDecode(data);
        return decodedData;
      } else {
        return "failed";
      }
    } catch (e) {
      return "failed";
    }
  }
} 