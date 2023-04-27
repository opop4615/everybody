import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;

class Infomations {
  static Future<List<Map<String, String>>> getInfomations(String ticker) async {
    if (ticker.isEmpty && ticker.length < 2) {
      print('ticker needs to be at least 3 chars');
      return Future.value([]);
    }


    var response = await http.get(Uri.parse('https://ipt9nj2vdb.execute-api.ap-northeast-2.amazonaws.com/everyvalue/info?code='+ticker));
    List<Infomation> infomations = [];
    if (response.statusCode == 200) {
      Iterable json = convert.jsonDecode(response.body);
      infomations =
          List<Infomation>.from(json.map((model) => Infomation.fromJson(model)));

      print('Number of Infomation: ${infomations.length}.');
    } else {
      print('Request failed with status: ${response.statusCode}.');
    }

    return Future.value(infomations
        .map((e) => {'Name': e.Name, 'Code': e.Code})
        .toList());
  }
}

class Infomation {
  final String Name;
  final String Code;

  Infomation({
    required this.Name,
    required this.Code,
  });

  factory Infomation.fromJson(Map<String, dynamic> json) {
    return Infomation(
      Name: json['Name'],
      Code: json['Code'],
    );
  }
}