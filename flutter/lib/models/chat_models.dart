// lib/models/chat_models.dart
class ChatRoom {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? current_concept;
  
  ChatRoom({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.current_concept,
  });
  
  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'],
      title: json['title'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      current_concept: json['current_concept'],
    );
  }
}

class Message {
  final String id;
  final String role;
  final String content;
  final DateTime createdAt;
  
  Message({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });
  
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      role: json['role'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}