import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;

class Tickers {
  static Future<List<Map<String, String>>> getSuggestions(String query) async {
    if (query.isEmpty && query.length < 2) {
      print('Query needs to be at least 3 chars');
      return Future.value([]);
    }


    var response = await http.get(Uri.parse('https://ipt9nj2vdb.execute-api.ap-northeast-2.amazonaws.com/everyvalue/ticker?code='+query));
    List<Suggestion> suggestions = [];
    if (response.statusCode == 200) {
      Iterable json = convert.jsonDecode(response.body);
      suggestions =
          List<Suggestion>.from(json.map((model) => Suggestion.fromJson(model)));

      print('Number of suggestion: ${suggestions.length}.');
    } else {
      print('Request failed with status: ${response.statusCode}.');
    }

    return Future.value(suggestions
        .map((e) => {'Name': e.Name, 'Code': e.Code})
        .toList());
  }
}

class Suggestion {
  final String Name;
  final String Code;

  Suggestion({
    required this.Name,
    required this.Code,
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      Name: json['Name'],
      Code: json['Code'],
    );
  }
}