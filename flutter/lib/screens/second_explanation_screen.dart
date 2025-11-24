// lib/screens/second_explanation_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/speech_service.dart';
import 'dart:async';

class SecondExplanationScreen extends StatefulWidget {
  final String concept;
  final String roomId;
  final String firstExplanation;
  final String firstReflection;

  const SecondExplanationScreen({
    Key? key,
    required this.concept,
    required this.roomId,
    required this.firstExplanation,
    required this.firstReflection,
  }) : super(key: key);

  @override
  _SecondExplanationScreenState createState() => _SecondExplanationScreenState();
}

class _SecondExplanationScreenState extends State<SecondExplanationScreen>
    with SingleTickerProviderStateMixin {
  
  final TextEditingController _inputController = TextEditingController();
  final SpeechService _speechService = SpeechService();
  bool _isRecording = false;
  String _recognizedText = '';
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }
  
  Timer? _restartTimer;

  // 음성 녹음 토글
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // 녹음 중지
      _restartTimer?.cancel();
      print('🎤 녹음 중지. 인식된 텍스트: "$_recognizedText"');
      await _speechService.stopListening();
      setState(() => _isRecording = false);
      
      if (_recognizedText.isEmpty) {
        print('⚠️ 인식된 텍스트가 없습니다');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('음성이 인식되지 않았습니다.')),
        );
        return;
      }
      
      print('📤 제출 시작: $_recognizedText');
      await _submitWithText(_recognizedText);
    } else {
      // 녹음 시작
      print('🎤 녹음 시작');
      bool initialized = await _speechService.initialize();
      if (!initialized) {
        print('❌ 음성 인식 초기화 실패');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('마이크 권한이 필요합니다')),
        );
        return;
      }
      
      setState(() {
        _isRecording = true;
        _recognizedText = '';
      });
      
      await _speechService.startListening(
        onResult: (text) {
          print('🎤 인식 중: $text');
          setState(() {
            _recognizedText = text;
          });
        },
      );
      
      // 1초마다 체크, 녹음 중이 아니면 바로 재시작
      _restartTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
        if (!_isRecording) {
          timer.cancel();
          return;
        }
        
        if (!_speechService.isListening) {
          print('⏰ 타이머: 녹음 중지 감지 → 재시작');
          await _speechService.restart();
        } else {
          print('⏰ 타이머: 녹음 중 → 대기');
        }
      });
    }
  }

  // 텍스트로 제출
  Future<void> _submitWithText(String text) async {
    if (text.trim().isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      await ApiService.saveMessage(widget.roomId, text, 'second_explanation');
      await ApiService.transitionPhase(widget.roomId, null);
      
      Navigator.pushReplacementNamed(
        context,
        '/second_reflection',
        arguments: {
          'roomId': widget.roomId,
          'concept': widget.concept,
          'firstExplanation': widget.firstExplanation,
          'firstReflection': widget.firstReflection,
          'secondExplanation': text,
        },
      );
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // _handleSubmit 수정
  Future<void> _handleSubmit() async {
    await _submitWithText(_inputController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
    onWillPop: () async => false,
    child: Scaffold(
        appBar: AppBar(
          title: Text('파인만 학습'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue.shade50, Colors.white],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 아이콘 (first_explanation과 똑같음)
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.edit_note,
                          size: 60,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      
                      SizedBox(height: 40),
                      
                      // 개념 표시
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.concept,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 30),
                      
                      // 질문 (다른 텍스트)
                      Text(
                        'AI 설명을 듣고 이해한 내용을\n다시 설명해주세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                          height: 1.4,
                        ),
                      ),
                      
                      SizedBox(height: 60),
                      
                      // 입력 영역 (완전히 똑같은 UI)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _inputController,
                              maxLines: 5,
                              decoration: InputDecoration(
                                hintText: '여기에 입력하세요...',
                                border: InputBorder.none,
                                hintStyle: TextStyle(color: Colors.grey.shade400),
                              ),
                              style: TextStyle(fontSize: 16),
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isLoading ? null : _toggleRecording,
                                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                                    label: Text(_isRecording ? '중지' : '음성'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isRecording ? Colors.red : Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isLoading ? null : _handleSubmit,
                                    icon: Icon(Icons.send),
                                    label: Text('전송'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_isRecording)
                              Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Text(
                                  '🎤 ${_recognizedText.isEmpty ? "말씀하세요..." : _recognizedText}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      if (_isLoading)
                        Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
     _restartTimer?.cancel();
    _animationController.dispose();
    _inputController.dispose();
    _speechService.dispose();
    super.dispose();
  }
}