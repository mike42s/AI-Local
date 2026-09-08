import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';

class RagState {
  final List<ChatMessage> messages;
  final bool isStreaming;
  final bool isIngesting;
  final String? ingestMessage;
  final String? errorMessage;

  RagState({
    required this.messages,
    this.isStreaming = false,
    this.isIngesting = false,
    this.ingestMessage,
    this.errorMessage,
  });

  RagState copyWith({
    List<ChatMessage>? messages,
    bool? isStreaming,
    bool? isIngesting,
    String? ingestMessage,
    String? errorMessage,
  }) {
    return RagState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      isIngesting: isIngesting ?? this.isIngesting,
      ingestMessage: ingestMessage,
      errorMessage: errorMessage,
    );
  }
}

class RagNotifier extends Notifier<RagState> {
  @override
  RagState build() {
    return RagState(messages: []);
  }

  String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      default:
        return 'http://localhost:3000';
    }
  }

  Future<void> sendMessageStream(
    String prompt, {
    List<int>? candidatePdfBytes,
  }) async {
    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty || state.isStreaming) return;

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: trimmedPrompt,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    final aiMessageId = '${DateTime.now().millisecondsSinceEpoch}_rag_ai';
    final aiMessagePlaceholder = ChatMessage(
      id: aiMessageId,
      text: '',
      sender: MessageSender.ai,
      timestamp: DateTime.now(),
      isStreaming: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage, aiMessagePlaceholder],
      isStreaming: true,
      errorMessage: null,
    );

    final client = http.Client();
    final url = Uri.parse('$_baseUrl/api/rag/stream');

    try {
      final request = http.Request('POST', url);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';

      final Map<String, dynamic> bodyPayload = {
        'prompt': trimmedPrompt,
      };

      if (candidatePdfBytes != null && candidatePdfBytes.isNotEmpty) {
        bodyPayload['candidatePdfBase64'] = base64Encode(candidatePdfBytes);
      }

      request.body = jsonEncode(bodyPayload);

      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Server returned status code ${response.statusCode}');
      }

      StringBuffer textBuffer = StringBuffer();

      final streamSubscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (String line) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6).trim();
            if (jsonStr.isNotEmpty) {
              try {
                final Map<String, dynamic> data = jsonDecode(jsonStr);
                if (data.containsKey('error')) {
                  textBuffer.write('\n[Error: ${data['error']}]');
                } else if (data.containsKey('text')) {
                  textBuffer.write(data['text']);
                }

                final isDone = data['done'] == true;

                _updateAiMessage(
                  aiMessageId,
                  textBuffer.toString(),
                  isStreaming: !isDone,
                );

                if (isDone) {
                  state = state.copyWith(isStreaming: false);
                }
              } catch (e) {
                // Ignore parse error
              }
            }
          }
        },
        onError: (error) {
          _updateAiMessage(
            aiMessageId,
            '${textBuffer.toString()}\n[RAG Stream Error: $error]',
            isStreaming: false,
          );
          state = state.copyWith(
            isStreaming: false,
            errorMessage: 'RAG error: $error',
          );
        },
        onDone: () {
          _updateAiMessage(
            aiMessageId,
            textBuffer.toString(),
            isStreaming: false,
          );
          state = state.copyWith(isStreaming: false);
          client.close();
        },
      );

      await streamSubscription.asFuture<void>().catchError((e) {
        state = state.copyWith(isStreaming: false);
      });
    } catch (e) {
      _updateAiMessage(
        aiMessageId,
        'Gagal terhubung ke RAG Engine: $e',
        isStreaming: false,
      );
      state = state.copyWith(
        isStreaming: false,
        errorMessage: 'Connection error: $e',
      );
      client.close();
    }
  }

  Future<bool> ingestDocument({required String content, String? title}) async {
    if (content.trim().isEmpty) return false;

    state = state.copyWith(isIngesting: true, ingestMessage: null, errorMessage: null);

    final url = Uri.parse('$_baseUrl/api/rag/ingest');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'content': content,
          'title': title,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        state = state.copyWith(
          isIngesting: false,
          ingestMessage: data['message'] ?? 'Dokumen SOP/Rules berhasil di-ingest!',
        );
        return true;
      } else {
        final err = data['error'] ?? 'Gagal meng-ingest dokumen.';
        state = state.copyWith(
          isIngesting: false,
          errorMessage: err,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isIngesting: false,
        errorMessage: 'Error koneksi ingest: $e',
      );
      return false;
    }
  }

  Future<bool> ingestPdfDocument({
    required List<int> pdfBytes,
    String? title,
  }) async {
    if (pdfBytes.isEmpty) return false;

    state = state.copyWith(isIngesting: true, ingestMessage: null, errorMessage: null);

    final url = Uri.parse('$_baseUrl/api/rag/ingest-pdf');

    try {
      final base64Pdf = base64Encode(pdfBytes);

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pdfBase64': base64Pdf,
          'title': title,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        state = state.copyWith(
          isIngesting: false,
          ingestMessage: data['message'] ?? 'File PDF SOP/Rules berhasil di-ingest ke pgvector!',
        );
        return true;
      } else {
        final err = data['error'] ?? 'Gagal meng-ingest file PDF.';
        state = state.copyWith(
          isIngesting: false,
          errorMessage: err,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isIngesting: false,
        errorMessage: 'Error koneksi PDF ingest: $e',
      );
      return false;
    }
  }

  void _updateAiMessage(String id, String newText, {required bool isStreaming}) {
    final updatedMessages = state.messages.map((msg) {
      if (msg.id == id) {
        return msg.copyWith(
          text: newText,
          isStreaming: isStreaming,
        );
      }
      return msg;
    }).toList();

    state = state.copyWith(messages: updatedMessages);
  }

  void clearChat() {
    state = RagState(messages: []);
  }
}

final ragProvider = NotifierProvider<RagNotifier, RagState>(RagNotifier.new);
