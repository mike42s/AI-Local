import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isStreaming;
  final String? errorMessage;

  ChatState({required this.messages, this.isStreaming = false, this.errorMessage});

  ChatState copyWith({List<ChatMessage>? messages, bool? isStreaming, String? errorMessage}) {
    return ChatState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      errorMessage: errorMessage,
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() {
    return ChatState(messages: []);
  }

  String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Use 10.0.2.2 for Android Emulator, or http://192.168.0.135:3000 if testing on a physical Android device over Wi-Fi
        return 'http://10.0.2.2:3000';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      default:
        return 'http://localhost:3000';
    }
  }

  Future<void> sendMessageStream(String prompt) async {
    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty || state.isStreaming) return;

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: trimmedPrompt,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    final aiMessageId = '${DateTime.now().millisecondsSinceEpoch}_ai';
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
    final url = Uri.parse('$_baseUrl/api/chat/stream');

    try {
      final request = http.Request('POST', url);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';
      request.body = jsonEncode({'prompt': trimmedPrompt});

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

                    _updateAiMessage(aiMessageId, textBuffer.toString(), isStreaming: !isDone);

                    if (isDone) {
                      state = state.copyWith(isStreaming: false);
                    }
                  } catch (e) {
                    // Ignore chunk parse error
                  }
                }
              }
            },
            onError: (error) {
              _updateAiMessage(aiMessageId, '${textBuffer.toString()}\n[Stream Error: $error]', isStreaming: false);
              state = state.copyWith(isStreaming: false, errorMessage: 'Stream error occurred: $error');
            },
            onDone: () {
              _updateAiMessage(aiMessageId, textBuffer.toString(), isStreaming: false);
              state = state.copyWith(isStreaming: false);
              client.close();
            },
          );

      await streamSubscription.asFuture<void>().catchError((e) {
        state = state.copyWith(isStreaming: false);
      });
    } catch (e) {
      _updateAiMessage(aiMessageId, 'Gagal terhubung ke backend AI: $e', isStreaming: false);
      state = state.copyWith(isStreaming: false, errorMessage: 'Connection error: $e');
      client.close();
    }
  }

  void _updateAiMessage(String id, String newText, {required bool isStreaming}) {
    final updatedMessages = state.messages.map((msg) {
      if (msg.id == id) {
        return msg.copyWith(text: newText, isStreaming: isStreaming);
      }
      return msg;
    }).toList();

    state = state.copyWith(messages: updatedMessages);
  }

  void clearChat() {
    state = ChatState(messages: []);
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);
