import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/support_models.dart';

class SupportState {
  const SupportState({
    this.isLoading = false,
    this.isSending = false,
    this.isConnected = false,
    this.isAdminTyping = false,
    this.error,
    this.conversation,
    this.messages = const [],
  });

  final bool isLoading;
  final bool isSending;
  final bool isConnected;
  final bool isAdminTyping;
  final String? error;
  final SupportConversation? conversation;
  final List<SupportMessage> messages;

  SupportState copyWith({
    bool? isLoading,
    bool? isSending,
    bool? isConnected,
    bool? isAdminTyping,
    String? error,
    SupportConversation? conversation,
    List<SupportMessage>? messages,
    bool clearError = false,
  }) {
    return SupportState(
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      isConnected: isConnected ?? this.isConnected,
      isAdminTyping: isAdminTyping ?? this.isAdminTyping,
      error: clearError ? null : (error ?? this.error),
      conversation: conversation ?? this.conversation,
      messages: messages ?? this.messages,
    );
  }
}

class SupportNotifier extends Notifier<SupportState> {
  io.Socket? _socket;
  Timer? _messageSyncTimer;
  Timer? _typingDebounceTimer;
  bool _typingSent = false;

  @override
  SupportState build() {
    ref.onDispose(_disconnect);
    return const SupportState();
  }

  Future<void> loadChat() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final conversationResponse =
          await ApiClient.instance.get('/support/conversation');
      final conversation = SupportConversation.fromJson(
        Map<String, dynamic>.from(conversationResponse.data),
      );

      final messagesResponse = await ApiClient.instance.get(
        '/support/conversations/${conversation.id}/messages',
        queryParameters: {'limit': 50},
      );
      final messages = (messagesResponse.data as List)
          .map((item) => SupportMessage.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      state = state.copyWith(
        isLoading: false,
        conversation: conversation,
        messages: messages,
      );

      _connect();
      _startMessageSync();
      await markRead();
    } on DioException catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: _extractError(error, 'Unable to load support chat.'),
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> sendMessage(String rawBody) async {
    final body = rawBody.trim();
    final conversation = state.conversation;
    if (body.isEmpty || conversation == null || state.isSending) {
      return;
    }

    _emitTyping(false);
    state = state.copyWith(isSending: true, clearError: true);
    try {
      final response = await ApiClient.instance.post(
        '/support/messages',
        data: {'body': body},
      );
      _handleSendResult(Map<String, dynamic>.from(response.data));
      state = state.copyWith(isSending: false);
    } on DioException catch (error) {
      state = state.copyWith(
        isSending: false,
        error: _extractError(error, 'Unable to send message.'),
      );
    } catch (error) {
      state = state.copyWith(isSending: false, error: error.toString());
    }
  }

  void onComposerChanged(String rawText) {
    if (state.conversation == null) {
      return;
    }

    final hasText = rawText.trim().isNotEmpty;
    if (hasText && !_typingSent) {
      _typingSent = true;
      _emitTyping(true);
    }

    _typingDebounceTimer?.cancel();
    if (!hasText) {
      _typingSent = false;
      _emitTyping(false);
      return;
    }

    _typingDebounceTimer = Timer(const Duration(milliseconds: 1200), () {
      _typingSent = false;
      _emitTyping(false);
    });
  }

  Future<void> markRead() async {
    final conversation = state.conversation;
    if (conversation == null) {
      return;
    }

    try {
      if (_socket?.connected == true) {
        _socket!.emit(
          'support:mark_read',
          {'conversationId': conversation.id},
        );
      }

      final response = await ApiClient.instance.patch(
        '/support/conversations/${conversation.id}/read',
      );
      state = state.copyWith(
        conversation: SupportConversation.fromJson(
          Map<String, dynamic>.from(response.data),
        ),
      );
    } catch (_) {
      // Read state is a nice-to-have for the user UI; do not interrupt chat.
    }
  }

  void _connect() {
    final token = ref.read(authProvider).token;
    if (token == null || token.isEmpty || state.conversation == null) {
      return;
    }

    if (_socket != null) {
      if (_socket!.connected) {
        return;
      }
      _disconnectSocketOnly();
    }

    final socketUrl = ApiClient.baseUrl.replaceFirst(RegExp(r'/$'), '');
    final socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .setReconnectionAttempts(12)
          .setReconnectionDelay(1000)
          .enableReconnection()
          .disableAutoConnect()
          .build(),
    );

    _socket = socket;
    socket.onConnect((_) {
      state = state.copyWith(isConnected: true);
      final conversation = state.conversation;
      if (conversation != null) {
        socket.emit('support:mark_read', {'conversationId': conversation.id});
      }
    });
    socket.onDisconnect((_) {
      state = state.copyWith(isConnected: false, isAdminTyping: false);
    });
    socket.onConnectError((payload) {
      final message = payload?.toString() ?? 'Support connection failed.';
      state = state.copyWith(isConnected: false, error: message);
    });
    socket.onError((payload) {
      final message = payload?.toString() ?? 'Support connection error.';
      state = state.copyWith(error: message);
    });
    socket.on('support:new_message', (payload) {
      if (payload is! Map) {
        return;
      }

      _handleSendResult(Map<String, dynamic>.from(payload));
      final conversation = state.conversation;
      final updated = payload['conversation'];
      if (updated is Map &&
          conversation != null &&
          updated['_id']?.toString() == conversation.id) {
        markRead();
      }
    });
    socket.on('support:typing', (payload) {
      if (payload is! Map) {
        return;
      }

      final conversation = state.conversation;
      if (conversation == null) {
        return;
      }

      if (payload['conversationId']?.toString() != conversation.id) {
        return;
      }

      if (payload['senderRole']?.toString() != 'admin') {
        return;
      }

      state = state.copyWith(isAdminTyping: payload['isTyping'] == true);
    });
    socket.on('support:conversation_updated', (payload) {
      if (payload is! Map) {
        return;
      }

      final conversation = state.conversation;
      if (conversation == null || payload['_id']?.toString() != conversation.id) {
        return;
      }

      state = state.copyWith(
        conversation: SupportConversation.fromJson(
          Map<String, dynamic>.from(payload),
        ),
      );
    });
    socket.on('support:messages_read', (payload) {
      if (payload is! Map) {
        return;
      }

      final conversation = state.conversation;
      if (conversation == null || payload['_id']?.toString() != conversation.id) {
        return;
      }

      state = state.copyWith(
        conversation: SupportConversation.fromJson(
          Map<String, dynamic>.from(payload),
        ),
      );
    });
    socket.on('support:error', (payload) {
      final message = payload is Map ? payload['message']?.toString() : null;
      state = state.copyWith(error: message ?? 'Support connection failed.');
    });
    socket.connect();
  }

  void _handleSendResult(Map<String, dynamic> payload) {
    final conversationPayload = payload['conversation'];
    final messagePayload = payload['message'];
    if (conversationPayload is! Map || messagePayload is! Map) {
      return;
    }

    final message = SupportMessage.fromJson(
      Map<String, dynamic>.from(messagePayload),
    );

    final nextConversation = SupportConversation.fromJson(
      Map<String, dynamic>.from(conversationPayload),
    );

    if (state.messages.any((item) => item.id == message.id)) {
      state = state.copyWith(conversation: nextConversation);
      return;
    }

    state = state.copyWith(
      conversation: nextConversation,
      messages: [...state.messages, message],
      isAdminTyping: message.isAdmin ? false : state.isAdminTyping,
    );
  }

  void _startMessageSync() {
    _messageSyncTimer?.cancel();
    _messageSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      await _refreshMessagesSilently();
    });
  }

  Future<void> _refreshMessagesSilently() async {
    final conversation = state.conversation;
    if (conversation == null) {
      return;
    }

    try {
      final messagesResponse = await ApiClient.instance.get(
        '/support/conversations/${conversation.id}/messages',
        queryParameters: {'limit': 50},
      );
      final fetched = (messagesResponse.data as List)
          .map((item) => SupportMessage.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      final currentIds = state.messages.map((item) => item.id).toSet();
      final fetchedIds = fetched.map((item) => item.id).toSet();
      if (currentIds.length != fetchedIds.length ||
          !currentIds.containsAll(fetchedIds)) {
        state = state.copyWith(messages: fetched);
      }
    } catch (_) {
      // Socket stream remains primary realtime path.
    }
  }

  void _emitTyping(bool isTyping) {
    final conversation = state.conversation;
    if (conversation == null || _socket?.connected != true) {
      return;
    }

    _socket!.emit('support:typing', {
      'conversationId': conversation.id,
      'isTyping': isTyping,
    });
  }

  void _disconnectSocketOnly() {
    _socket?.clearListeners();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void _disconnect() {
    _messageSyncTimer?.cancel();
    _messageSyncTimer = null;
    _typingDebounceTimer?.cancel();
    _typingDebounceTimer = null;
    _typingSent = false;
    _emitTyping(false);
    _disconnectSocketOnly();
  }

  String _extractError(DioException error, String fallback) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      final message = data['message'];
      if (message is List) {
        return message.join(', ');
      }
      return message.toString();
    }
    return fallback;
  }
}

final supportProvider = NotifierProvider<SupportNotifier, SupportState>(
  SupportNotifier.new,
);
