// lib/screens/chat_screen.dart (화면 전환 방식)
import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import '../services/api_service.dart';
import '../models/chat_models.dart';
import '../models/learning_models.dart';
import 'dart:convert'; 
import 'package:file_picker/file_picker.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // 채팅 관련 변수
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final WebSocketService _wsService = WebSocketService();
  String _currentAiMessage = '';
  bool _isAiTyping = false;
  bool _isLoadingMessages = false;
  
  // 채팅방 관련 변수
  ChatRoom? _currentRoom;
  List<ChatRoom> _chatRooms = [];
  bool _isLoadingRooms = true;
  bool _showChatList = false;

  

  // 파인만 학습 관련
  PhaseInfo? _currentPhase;

  // 삭제 모드 관련
  bool _isDeleteMode = false;
  Set<String> _selectedRoomIds = {};

  // PDF 업로드 관련
  bool _isUploadingPdf = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
    _initializeChat();  // 지연 실행
    });
  }

  // 초기화
  Future<void> _initializeChat() async {
    await _loadChatRooms();
    
    if (_chatRooms.isEmpty) {
      await _createChatRoom("파인만 학습");
    } else {
      _selectChatRoom(_chatRooms.first);
    }
  }

  // 채팅방 목록 로드
  Future<void> _loadChatRooms() async {
    setState(() => _isLoadingRooms = true);
    
    try {
      final rooms = await ApiService.getChatRooms();
      setState(() {
        _chatRooms = rooms;
        _isLoadingRooms = false;
      });
    } catch (e) {
      print('Error loading rooms: $e');
      setState(() => _isLoadingRooms = false);
    }
  }

  // 새 채팅방 생성
  Future<void> _createChatRoom(String title) async {
    try {
      final room = await ApiService.createChatRoom(title);
      setState(() {
        _chatRooms.insert(0, room);
      });
      _selectChatRoom(room);
    } catch (e) {
      print('Error creating room: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('채팅방 생성 실패')),
      );
    }
  }

  // 채팅방 선택
  void _selectChatRoom(ChatRoom room) async{
    _wsService.dispose();
    
    setState(() {
      _currentRoom = room;
      _messages.clear();
      _currentAiMessage = '';
      _isAiTyping = false;
      _showChatList = false;
      _isLoadingMessages = true;
    });

    await _loadLearningPhase(room.id);
    _loadPreviousMessages(room.id);
    _connectToServer(room.id);
  }

  // 학습 단계 조회
  Future<void> _loadLearningPhase(String roomId) async {
    try {
      final phase = await ApiService.getLearningPhase(roomId);
      setState(() {
        _currentPhase = phase;
      });
      
      // KNOWLEDGE_CHECK 단계면 지식 확인 화면으로 이동
      if (phase.phase == LearningPhase.KNOWLEDGE_CHECK && _currentRoom != null) {
        _navigateToKnowledgeCheck();
      }
    } catch (e) {
      print('Error loading phase: $e');
    }
  }
  
  // 지식 확인 화면으로 이동
  Future<void> _navigateToKnowledgeCheck() async {
    if (_currentRoom == null) return;
    
    // 화면 전환
    await Navigator.pushNamed(
      context,
      '/knowledge_check',
      arguments: {
        'concept': _currentRoom!.current_concept ?? '개념',
        'roomId': _currentRoom!.id,
      },
    );
    
    // 학습 완료 후 돌아왔을 때 메시지 다시 로드
    await _loadPreviousMessages(_currentRoom!.id);
    // 화면에서 돌아왔을 때 단계 재조회
    await _loadLearningPhase(_currentRoom!.id);
  }

  // 이전 메시지 불러오기
  Future<void> _loadPreviousMessages(String roomId) async {
    
    try {
      final messages = await ApiService.getMessages(roomId);
      setState(() {
        _messages.clear();
        _messages.addAll(messages
          .where((msg) => !_isMetaMessage(msg.content))  // 메타 메시지 필터링
          .map((msg) => ChatMessage(
            text: msg.content,
            isUser: msg.role == 'user',
          )).toList());
        _isLoadingMessages = false;
      });
      _scrollToBottom();
    } catch (e) {
      print('Error loading messages: $e');
      setState(() => _isLoadingMessages = false);
    }
  }
  
  

  // WebSocket 연결
  void _connectToServer(String roomId) {
    _wsService.connectToRoom(roomId, (data) {
      setState(() {
        if (data['type'] == 'stream') {
          _isAiTyping = true;
          _currentAiMessage += data['content'];
        } else if (data['type'] == 'complete') {
          _messages.add(ChatMessage(
            text: _currentAiMessage,
            isUser: false,
          ));
          _currentAiMessage = '';
          _isAiTyping = false;
          _loadLearningPhase(roomId);
        } 
        else if(data['type'] == 'phase_changed') {
          _loadLearningPhase(roomId);
        }
        else if (data['error'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${data['error']}')),
          );
        }
      });
      _scrollToBottom();
    });
  }

  // 메시지 전송
  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    if (_currentRoom == null) return;
    
    setState(() {
      _messages.add(ChatMessage(
        text: _controller.text,
        isUser: true,
      ));
    });
    
    _wsService.sendMessage(_controller.text);
    _controller.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // 전체 선택/해제
  void _toggleSelectAll() {
    setState(() {
      if (_selectedRoomIds.length == _chatRooms.length) {
        _selectedRoomIds.clear();
      } else {
        _selectedRoomIds = _chatRooms.map((room) => room.id).toSet();
      }
    });
  }

  // 선택된 채팅방 삭제
  Future<void> _deleteSelectedRooms() async {
    if (_selectedRoomIds.isEmpty) return;
    
    final deleteCount = _selectedRoomIds.length; // 개수 먼저 저장
    
    try {
      final success = await ApiService.deleteMultipleChatRooms(_selectedRoomIds.toList());
      
      if (success) {
        // 삭제된 방이 현재 선택된 방이면 초기화
        if (_currentRoom != null && _selectedRoomIds.contains(_currentRoom!.id)) {
          _wsService.dispose();
          setState(() {
            _currentRoom = null;
            _messages.clear();
          });
        }
        
        setState(() {
          _selectedRoomIds.clear();
          _isDeleteMode = false;
        });
        
        // 채팅방 목록 새로고침
        await _loadChatRooms();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$deleteCount개 채팅방 삭제됨')),
        );
      }
    } catch (e) {
      print('Error deleting rooms: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패')),
      );
    }
  }

  // PDF 파일 선택 및 업로드
  Future<void> _pickAndUploadPdf() async {
    if (_currentRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('채팅방을 먼저 선택하세요')),
      );
      return;
    }

    try {
      // 파일 선택
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isUploadingPdf = true);

        // 안내 다이얼로그
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('PDF 업로드 중'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('파일을 업로드하고 있습니다...\n최대 10MB까지 가능합니다.'),
              ],
            ),
          ),
        );

        // 업로드
        bool success = await ApiService.uploadPdf(
          _currentRoom!.id,
          result.files.single.path!,
        );

        Navigator.pop(context); // 로딩 다이얼로그 닫기

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ PDF 업로드 완료! 이제 자료 기반으로 학습할 수 있습니다.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ PDF 업로드 실패. 파일을 확인해주세요.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error picking PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('파일 선택 오류: $e')),
      );
    } finally {
      setState(() => _isUploadingPdf = false);
    }
  }

  // 새 채팅방 생성 다이얼로그
  void _showNewChatDialog() {
    final titleController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('새 채팅방'),
        content: TextField(
          controller: titleController,
          decoration: InputDecoration(
            hintText: '채팅방 제목을 입력하세요',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                _createChatRoom(titleController.text);
                Navigator.pop(context);
              }
            },
            child: Text('생성'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_currentRoom?.title ?? 'AI Chat'),
            if (_currentPhase != null && _currentPhase!.title.isNotEmpty)
              Text(
                _currentPhase!.title,
                style: TextStyle(fontSize: 12),
              ),
          ],
        ),
        elevation: 2,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(_showChatList ? Icons.chat : Icons.menu),
          onPressed: () {
            setState(() {
              _showChatList = !_showChatList;
              if (!_showChatList) {
                _isDeleteMode = false;
                _selectedRoomIds.clear();
              }
            });
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_comment),
            tooltip: '새 채팅',
            onPressed: _showNewChatDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 메인 채팅 화면 (버튼과 박스 UI 모두 제거)
          Column(
            children: [
              if (_isLoadingMessages) LinearProgressIndicator(),
              
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(16),
                  itemCount: _messages.length + (_isAiTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < _messages.length) {
                      return ChatBubble(message: _messages[index]);
                    } else {
                      return ChatBubble(
                        message: ChatMessage(
                          text: _currentAiMessage,
                          isUser: false,
                        ),
                        isTyping: true,
                      );
                    }
                  },
                ),
              ),
              _buildInputArea(),
            ],
          ),
          
          // 반투명 배경 (채팅 목록이 열렸을 때)
          if (_showChatList)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showChatList = false;
                    _isDeleteMode = false;
                    _selectedRoomIds.clear();
                  });
                },
                child: Container(
                  color: Colors.black26,
                ),
              ),
            ),

          // 채팅 목록 (슬라이드 메뉴)
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            left: _showChatList ? 0 : -MediaQuery.of(context).size.width * 0.75,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.75,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(2, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    color: Colors.blue.shade50,
                    child: Row(
                      children: [
                        if (_isDeleteMode)
                        Checkbox(
                          value: _selectedRoomIds.length == _chatRooms.length && _chatRooms.isNotEmpty,
                          onChanged: (_) => _toggleSelectAll(),
                        )
                      else
                        Icon(Icons.chat_bubble_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isDeleteMode ? '채팅방 선택' : '채팅 목록',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_isDeleteMode)
                        TextButton(
                          onPressed: _deleteSelectedRooms,
                          child: Text(
                            '삭제',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _isDeleteMode = true;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _isLoadingRooms
                        ? Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: _chatRooms.length,
                            itemBuilder: (context, index) {
                              final room = _chatRooms[index];
                              final isSelected = room.id == _currentRoom?.id;
                              
                              return ListTile(
                                leading: _isDeleteMode
                                  ? Checkbox(
                                      value: _selectedRoomIds.contains(room.id),
                                      onChanged: (checked) {
                                        setState(() {
                                          if (checked == true) {
                                            _selectedRoomIds.add(room.id);
                                          } else {
                                            _selectedRoomIds.remove(room.id);
                                          }
                                        });
                                      },
                                    )
                                  : CircleAvatar(
                                      backgroundColor: isSelected ? Colors.blue : Colors.grey.shade300,
                                      child: Icon(
                                        Icons.chat,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                title: Text(
                                  room.title,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Text(
                                  '${room.updatedAt.toString().split(' ')[0]}',
                                  style: TextStyle(fontSize: 12),
                                ),
                                selected: isSelected,
                                selectedTileColor: Colors.blue.shade50,
                                onTap: () {
                                  if (_isDeleteMode) {
                                    setState(() {
                                      if (_selectedRoomIds.contains(room.id)) {
                                        _selectedRoomIds.remove(room.id);
                                      } else {
                                        _selectedRoomIds.add(room.id);
                                      }
                                    });
                                  } else {
                                    _selectChatRoom(room);
                                  }
                                },
                              );
                            },
                          ),
                  ),
                  Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.add_circle_outline, color: Colors.blue),
                    title: Text('새 채팅 시작'),
                    onTap: () {
                      setState(() => _showChatList = false);
                      _showNewChatDialog();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            offset: Offset(0, -2),
            blurRadius: 4,
            color: Colors.black12,
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: Colors.red),
            onPressed: _isUploadingPdf ? null : _pickAndUploadPdf,
            tooltip: 'PDF 업로드',
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
              enabled: _currentRoom != null,
            ),
          ),
          SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: _currentRoom != null ? Colors.blue : Colors.grey,
            child: IconButton(
              icon: Icon(Icons.send, color: Colors.white),
              onPressed: _currentRoom != null ? _sendMessage : null,
            ),
          ),
        ],
      ),
    );
  }

   // 메타 메시지 체크 함수
  bool _isMetaMessage(String content) {
    return content.contains('위 내용을 바탕으로') || 
           content.contains('다음 평가 기준에 따라');
  }

  @override
  void dispose() {
    _wsService.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// 채팅 메시지 모델
class ChatMessage {
  final String text;
  final bool isUser;
  
  ChatMessage({required this.text, required this.isUser});
}

// 채팅 버블 위젯
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isTyping;
  
  ChatBubble({required this.message, this.isTyping = false});
  
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isUser ? Colors.white : Colors.black87,
              ),
            ),
            if (isTyping)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'AI가 입력 중...',
                  style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: message.isUser ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}