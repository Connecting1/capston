import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class SpeechService {
  stt.SpeechToText? _speech;
  bool _shouldKeepListening = false;
  Function(String)? _onResultCallback;
  String _accumulatedText = '';
  String _currentSessionText = '';
  
  // 초기화 - 매번 새로 생성
  Future<bool> initialize() async {
    // 기존 인스턴스 정리
    if (_speech != null) {
      await _speech!.stop();
      _speech = null;
    }
    
    // 새 인스턴스 생성
    _speech = stt.SpeechToText();
    
    var status = await Permission.microphone.request();
    if (!status.isGranted) {
      print('❌ 마이크 권한 거부됨');
      return false;
    }
    
    bool initialized = await _speech!.initialize(
      onError: (error) => print('❌ 음성 인식 오류: $error'),
      onStatus: (status) => print('🎤 상태: $status'),
    );
    
    return initialized;
  }
  
  // 녹음 시작
  Future<void> startListening({
    required Function(String) onResult,
  }) async {
    // 매번 새로 초기화
    await initialize();
    
    _shouldKeepListening = true;
    _onResultCallback = onResult;
    _accumulatedText = '';
    
    print('🎤 한국어 로케일로 시작');
    await _startListeningInternal();
  }

  // 내부 녹음 시작
  Future<void> _startListeningInternal() async {
    if (_speech == null) return;
    
    _currentSessionText = '';
    
    await _speech!.listen(
      onResult: (result) {
        _currentSessionText = result.recognizedWords;
        
        String fullText = _accumulatedText.isEmpty 
            ? _currentSessionText 
            : '$_accumulatedText $_currentSessionText';
            
        print('🎤 현재: "$_currentSessionText" | 전체: "$fullText"');
        _onResultCallback?.call(fullText.trim());
      },
      localeId: 'ko_KR',
      cancelOnError: false,
      partialResults: true,
      listenMode: stt.ListenMode.dictation,
      onDevice: false,
      listenFor: Duration(minutes: 10),  // 10분으로 설정
      pauseFor: Duration(seconds: 10),   // 10초 침묵까지 허용
    );
  }

  // 수동 재시작 (외부에서 호출)
  Future<void> restart() async {
    print('🔄 수동 재시작 요청');
    
    // 현재 세션 결과 누적
    if (_currentSessionText.isNotEmpty) {
      if (_accumulatedText.isEmpty) {
        _accumulatedText = _currentSessionText;
      } else {
        _accumulatedText = '$_accumulatedText $_currentSessionText';
      }
      print('💾 누적 저장: "$_accumulatedText"');
    }
    
    if (_shouldKeepListening && _speech != null) {
      await _speech!.stop();
      await Future.delayed(Duration(milliseconds: 200));
      await _startListeningInternal();
      print('▶️ 녹음 재개 완료');
    }
  }
  
  // 녹음 중지
  Future<String> stopListening() async {
    _shouldKeepListening = false;
    
    if (_speech != null) {
      await _speech!.stop();
    }
    
    String finalText = _accumulatedText.isEmpty 
        ? _currentSessionText 
        : '$_accumulatedText $_currentSessionText';
        
    return finalText.trim();
  }
  
  bool get isListening => _speech?.isListening ?? false;
  
  void dispose() {
    _shouldKeepListening = false;
    _speech?.stop();
    _speech = null;
  }
}