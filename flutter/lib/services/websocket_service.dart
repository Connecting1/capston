// lib/services/websocket_service.dart
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  String? _currentRoomId;
  bool _isConnected = false;
  
  // 연결 상태 확인
  bool get isConnected => _isConnected;
  String? get currentRoomId => _currentRoomId;
  
  // room ID를 사용한 연결
  void connectToRoom(String roomId, Function(Map<String, dynamic>) onMessage) {
    try {
      // 이전 연결이 있으면 종료
      if (_channel != null) {
        dispose();
      }
      
      _currentRoomId = roomId;
      print('🔌 Connecting to room: $roomId');
      
      final wsUrl = '${AppConfig.wsUrl}/ws/chat/$roomId';
      print('WebSocket URL: $wsUrl');
      
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      
      _channel!.stream.listen(
        (data) {
          try {
            final decoded = json.decode(data);
            onMessage(decoded);
          } catch (e) {
            print('❌ Error decoding message: $e');
          }
        },
        onError: (error) {
          print('❌ WebSocket Error: $error');
          _isConnected = false;
          onMessage({'type': 'error', 'content': 'Connection error: $error'});
        },
        onDone: () {
          print('🔌 WebSocket connection closed for room: $roomId');
          _isConnected = false;
        },
        cancelOnError: false,
      );
      
      print('✅ WebSocket connected to room: $roomId');
    } catch (e) {
      print('❌ Failed to connect to room: $e');
      _isConnected = false;
      onMessage({'type': 'error', 'content': 'Failed to connect: $e'});
    }
  }
  
  // 메시지 전송
  void sendMessage(String message) {
    if (_channel != null && _isConnected) {
      try {
        final data = json.encode({'message': message});
        _channel!.sink.add(data);
        print('📤 Message sent: $message');
      } catch (e) {
        print('❌ Error sending message: $e');
      }
    } else {
      print('⚠️ Cannot send message: Not connected');
    }
  }
  
  // 연결 종료
  void dispose() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
    _currentRoomId = null;
    _isConnected = false;
    print('🔌 WebSocket disposed');
  }
  
  // 재연결
  void reconnect(String roomId, Function(Map<String, dynamic>) onMessage) {
    dispose();
    Future.delayed(Duration(seconds: 1), () {
      connectToRoom(roomId, onMessage);
    });
  }
}