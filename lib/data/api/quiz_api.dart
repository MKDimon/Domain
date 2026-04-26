import '../../core/api/api_client.dart';

class QuizApi {
  final ApiClient _client;
  QuizApi(this._client);

  Future<Map<String, dynamic>> submit(int sectionId, {required String mode, required int score, required int total}) =>
      _client.post('/sections/$sectionId/quiz/submit', data: {'mode': mode, 'score': score, 'total': total});

  Future<Map<String, dynamic>> myResult(int sectionId) =>
      _client.get<Map<String, dynamic>>('/sections/$sectionId/quiz/my-result');

  Future<Map<String, dynamic>> stats(int sectionId) =>
      _client.get<Map<String, dynamic>>('/sections/$sectionId/quiz/stats');
}
