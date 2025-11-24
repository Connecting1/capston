// lib/screens/evaluation_screen.dart
import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import '../services/api_service.dart';

class EvaluationScreen extends StatefulWidget {
  final String roomId;
  final String concept;
  final String firstExplanation;
  final String firstReflection;
  final String secondExplanation;
  final String secondReflection;

  const EvaluationScreen({
    Key? key,
    required this.roomId,
    required this.concept,
    required this.firstExplanation,
    required this.firstReflection,
    required this.secondExplanation,
    required this.secondReflection,
  }) : super(key: key);

  @override
  _EvaluationScreenState createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  final WebSocketService _wsService = WebSocketService();
  final ScrollController _scrollController = ScrollController();
  
  String _evaluation = '';
  bool _isLoading = true;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _connectAndRequestEvaluation();
  }

  void _connectAndRequestEvaluation() {
    _wsService.connectToRoom(widget.roomId, (data) {
      setState(() {
        if (data['type'] == 'stream') {
          _isTyping = true;
          _isLoading = false;
          _evaluation += data['content'];
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
    
    // 평가 요청 메시지 전송
    Future.delayed(Duration(milliseconds: 500), () {
      final evaluationRequest = '''
개념: ${widget.concept}

첫 번째 설명: ${widget.firstExplanation}
첫 번째 성찰: ${widget.firstReflection}

두 번째 설명: ${widget.secondExplanation}
두 번째 성찰: ${widget.secondReflection}

위 내용을 바탕으로 다음 평가 기준에 따라 분석하고 피드백을 제공해주세요:

1. 이해도 - 핵심 개념 파악 정도, 오개념 유무, 개선된 부분
2. 표현력 - 설명의 명확성, 전문 용어 사용 정도, 비유와 예시 활용
3. 응용력 - 기존 지식과의 연결, 실생활 적용 가능성
4. 메타인지 능력 - 자신의 부족함을 인식하는 정도, 객관적 자기 평가 능력
5. 배경 지식 수준 - 현재 보유 지식 분석, 추가 학습 필요 영역

각 항목별로 2-3문장의 구체적이고 건설적인 피드백을 제공해주세요.
''';
      
      _wsService.sendMessage(evaluationRequest);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('학습 평가'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.home),
            tooltip: '홈으로',
            onPressed: () {
              // ChatScreen으로 돌아가기
              Navigator.popUntil(context, (route) => route.isFirst);
            },
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
                    Icons.assessment,
                    size: 50,
                    color: Colors.blue.shade700,
                  ),
                  SizedBox(height: 12),
                  Text(
                    '종합 평가',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '당신의 학습 과정을 분석했습니다',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            Divider(height: 1),
            
            // 평가 내용
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 20),
                          Text(
                            'AI가 평가를 작성하고 있어요...',
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
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.shade200,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.emoji_events,
                                  color: Colors.green.shade700,
                                  size: 28,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '학습 완료!',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade900,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        widget.concept,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: 24),
                          
                          // 평가 내용
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
                                  _evaluation.isEmpty 
                                      ? '평가를 기다리는 중...' 
                                      : _evaluation,
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
                                          'AI가 평가 중...',
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
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: 다시 학습하기 기능
                          Navigator.popUntil(context, (route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.grey.shade700,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh),
                            SizedBox(width: 8),
                            Text(
                              '다시 학습하기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                              await ApiService.transitionPhase(widget.roomId, 'complete');
                              Navigator.popUntil(context, (route) => route.isFirst);
                            } catch (e) {
                              print('Error: $e');
                            }
                        },
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
                            Icon(Icons.check_circle),
                            SizedBox(width: 8),
                            Text(
                              '학습 완료',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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