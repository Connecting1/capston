// lib/screens/ai_explanation_screen.dart (수정본)
import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import '../services/api_service.dart';

class AIExplanationScreen extends StatefulWidget {
  final String roomId;
  final String concept;
  final String? explanation;
  final String? reflection;

  const AIExplanationScreen({
    Key? key,
    required this.roomId,
    required this.concept,
    this.explanation,
    this.reflection,
  }) : super(key: key);

  @override
  _AIExplanationScreenState createState() => _AIExplanationScreenState();
}

class _AIExplanationScreenState extends State<AIExplanationScreen> {
  final WebSocketService _wsService = WebSocketService();
  final ScrollController _scrollController = ScrollController();
  
  String _aiExplanation = '';
  bool _isLoading = true;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _connectAndRequestExplanation();
  }

  void _connectAndRequestExplanation() {
    _wsService.connectToRoom(widget.roomId, (data) {
      setState(() {
        if (data['type'] == 'stream') {
          _isTyping = true;
          _isLoading = false;
          _aiExplanation += data['content'];
          _scrollToBottom();
        } else if (data['type'] == 'complete') {
          _isTyping = false;
        } else if (data['error'] != null) {
          _isLoading = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('오류: ${data['error']}')),
          );
        }
      });
    });
    
    // AI 설명 요청 메시지 전송
    Future.delayed(Duration(milliseconds: 500), () {
      if (widget.explanation != null && widget.reflection != null) {
        // "알고 있다" 경로
        _wsService.sendMessage(
          '사용자 설명: ${widget.explanation}\n성찰: ${widget.reflection}\n\n위 내용을 바탕으로 개념을 설명해주세요.'
        );
      } else {
        // "모른다" 경로
        _wsService.sendMessage('${widget.concept}에 대해 설명해주세요.');
      }
    });
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

  // 두 번째 설명 단계로 이동
  void _goToSecondExplanation() async {
  try {
    // 추가: API 호출
    await ApiService.transitionPhase(widget.roomId, null);
    
    Navigator.pushReplacementNamed(
      context,
      '/second_explanation',
      arguments: {
        'roomId': widget.roomId,
        'concept': widget.concept,
        'firstExplanation': widget.explanation ?? '',
        'firstReflection': widget.reflection ?? '',
      },
    );
  } catch (e) {
    print('Error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('오류가 발생했습니다: $e')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.concept),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.check_circle),
            tooltip: '다음 단계',
            onPressed: _isLoading ? null : _goToSecondExplanation,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            // 헤더
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.school,
                    size: 50,
                    color: Colors.blue.shade700,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'AI 선생님의 설명',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),
            
            Divider(height: 1),
            
            // AI 설명 내용
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 20),
                          Text(
                            'AI가 설명을 준비하고 있어요...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      controller: _scrollController,
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 개념 박스
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue.shade200,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  color: Colors.blue.shade700,
                                  size: 28,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    widget.concept,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: 24),
                          
                          // AI 설명
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _aiExplanation.isEmpty 
                                      ? '설명을 기다리는 중...' 
                                      : _aiExplanation,
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.6,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                if (_isTyping)
                                  Padding(
                                    padding: EdgeInsets.only(top: 12),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'AI가 입력 중...',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: 80),
                        ],
                      ),
                    ),
            ),
            
            // 하단 버튼
            if (!_isLoading)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _goToSecondExplanation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_forward),
                        SizedBox(width: 8),
                        Text(
                          '다음 단계로',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _wsService.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}