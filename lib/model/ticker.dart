import 'dart:math';

class BackendService {
  static Future<List> getSuggestios(String query) async {
    await Future.delayed(Duration(seconds: 1));

    return List.generate(3, (index) {
      return {'name': query + index.toString(), 'code': Random().nextInt(100)};
    });
  }
}
