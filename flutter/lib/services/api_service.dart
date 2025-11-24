// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/chat_models.dart';
import '../models/learning_models.dart';

class ApiService {
  static final String baseUrl = AppConfig.baseUrl;
  
  // 채팅방 목록 조회
  static Future<List<ChatRoom>> getChatRooms() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/rooms'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => ChatRoom.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load chat rooms: ${response.statusCode}');
      }
    } catch (e) {
      print('API Error (getChatRooms): $e');
      throw e;
    }
  }
  
  // 채팅방 생성
  static Future<ChatRoom> createChatRoom(String title) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/rooms'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'title': title}),
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return ChatRoom.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create chat room: ${response.statusCode}');
      }
    } catch (e) {
      print('API Error (createChatRoom): $e');
      throw e;
    }
  }
  
  // 메시지 조회
  static Future<List<Message>> getMessages(String roomId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/rooms/$roomId/messages'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((json) => Message.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      print('API Error (getMessages): $e');
      throw e;
    }
  }
  
  // 채팅방 삭제 (선택사항)
  static Future<bool> deleteChatRoom(String roomId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/rooms/$roomId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      print('API Error (deleteChatRoom): $e');
      return false;
    }
  }

  // 여러 채팅방 한 번에 삭제
  static Future<bool> deleteMultipleChatRooms(List<String> roomIds) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/rooms/delete-multiple'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'room_ids': roomIds,
        }),
      ).timeout(Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      print('API Error (deleteMultipleChatRooms): $e');
      return false;
    }
  }

  // 현재 학습 단계 조회
  static Future<PhaseInfo> getLearningPhase(String roomId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/learning/phase/$roomId'),
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return PhaseInfo.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to get learning phase');
      }
    } catch (e) {
      print('API Error (getLearningPhase): $e');
      throw e;
    }
  }
  
  // 학습 단계 전환
  static Future<Map<String, dynamic>> transitionPhase(
    String roomId, 
    String? userChoice
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/learning/transition'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'room_id': roomId,
          'user_choice': userChoice,
        }),
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to transition phase');
      }
    } catch (e) {
      print('API Error (transitionPhase): $e');
      throw e;
    }
  }


  // 메시지 저장 API (AI 응답 없이)
  static Future<void> saveMessage(String roomId, String content, String phase) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/rooms/$roomId/messages'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'content': content,
          'role': 'user',
          'phase': phase,
        }),
      ).timeout(Duration(seconds: 10));
    } catch (e) {
      print('API Error (saveMessage): $e');
      throw e;
    }
  }

  // PDF 업로드
  static Future<bool> uploadPdf(String roomId, String filePath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/rooms/$roomId/upload-pdf'),
      );
      
      // 파일 추가
      request.files.add(
        await http.MultipartFile.fromPath('file', filePath),
      );
      
      var response = await request.send().timeout(Duration(seconds: 60));
      
      if (response.statusCode == 200) {
        print('✅ PDF 업로드 성공');
        return true;
      } else {
        var responseBody = await response.stream.bytesToString();
        print('❌ PDF 업로드 실패: $responseBody');
        return false;
      }
    } catch (e) {
      print('API Error (uploadPdf): $e');
      return false;
    }
  }
}