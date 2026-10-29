import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../models/realtime_models.dart';

abstract class RealtimeRemoteDataSource {
  /// Trade the Bearer token for a single-use websocket ticket.
  Future<RealtimeTicketModel> fetchTicket();
}

class RealtimeRemoteDataSourceImpl implements RealtimeRemoteDataSource {
  final ApiClient apiClient;

  RealtimeRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<RealtimeTicketModel> fetchTicket() async {
    final response = await apiClient.post<RealtimeTicketModel>(
      ApiConstants.realtimeTicket,
      body: const {},
      retryOnNetworkError: false,
      parser: (json) =>
          RealtimeTicketModel.fromJson(json as Map<String, dynamic>),
    );
    if (response.data == null) {
      throw const AppException('Realtime ticket response was empty');
    }
    return response.data!;
  }
}
