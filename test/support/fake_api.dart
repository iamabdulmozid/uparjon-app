import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// One canned reply. [body] is encoded as-is, so it may be a bare list for the
/// endpoints that answer without the `{success, data}` envelope.
typedef FakeReply = ({int status, Object? body});

FakeReply ok(Object? data, {String message = 'OK'}) =>
    (status: 200, body: {'success': true, 'message': message, 'data': data});

FakeReply apiError(
  String errorCode, {
  int status = 400,
  String message = 'Failed',
}) => (
  status: status,
  body: {'success': false, 'errorCode': errorCode, 'message': message},
);

/// A response with no envelope at all — `GET /mobile/ads/feed` and the quiz
/// and survey lists answer with a bare JSON array.
FakeReply rawJson(Object? body) => (status: 200, body: body);

/// Dio transport that answers from a routing table instead of the network.
///
/// Tests exercise the real [ApiClient] envelope handling and the real
/// repositories — only the wire is faked.
class FakeApi implements HttpClientAdapter {
  FakeApi(
    this.routes, {
    Map<String, List<FakeReply>>? sequences,
    this.offline = false,
  }) : sequences = sequences ?? {};

  /// When true every request fails the way a device with no connectivity
  /// does — a transport error, not an HTTP response.
  bool offline;

  /// Keyed by `"METHOD /path"`, e.g. `"POST /auth/login"`.
  final Map<String, FakeReply> routes;

  /// Replies consumed in order for a route; the last one repeats once the
  /// list runs out. Use it to model "fails, then succeeds after a refresh".
  final Map<String, List<FakeReply>> sequences;

  /// Every request that was made, in order.
  final List<RequestOptions> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);

    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'No internet connection',
      );
    }

    final key = '${options.method} ${options.path}';

    final queued = sequences[key];
    final reply = queued != null && queued.isNotEmpty
        ? (queued.length == 1 ? queued.first : queued.removeAt(0))
        : routes[key] ??
              (status: 404, body: {'success': false, 'errorCode': 'NOT_FOUND'});

    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  /// How many times `"METHOD /path"` was requested.
  int callCount(String key) =>
      calls.where((c) => '${c.method} ${c.path}' == key).length;

  /// The headers sent with `"METHOD /path"`, or null if it was never called.
  Map<String, dynamic>? headersOf(String key) {
    for (final call in calls) {
      if ('${call.method} ${call.path}' == key) return call.headers;
    }
    return null;
  }

  /// The JSON body sent to `"METHOD /path"`, or null if it was never called.
  Map<String, dynamic>? bodyOf(String key) {
    for (final call in calls) {
      if ('${call.method} ${call.path}' == key) {
        final data = call.data;
        if (data is Map) return data.cast<String, dynamic>();
      }
    }
    return null;
  }

  /// Dio wired to this fake transport, for `ApiClient(ref, dio: ...)`.
  ///
  /// Riverpod 3 does not export the `Override` type, so the provider override
  /// is built at the call site where inference handles it (see `pumpApp`).
  Dio get dio => Dio(
    BaseOptions(
      baseUrl: 'https://fake.test/api/v1',
      // Mirror ApiClient: non-2xx must reach the envelope parser.
      validateStatus: (status) => status != null && status < 500,
    ),
  )..httpClientAdapter = this;
}
