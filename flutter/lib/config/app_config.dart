// lib/config/app_config.dart
class AppConfig {
  // 개발 중에는 실제 컴퓨터 IP 사용
  // 에뮬레이터: 10.0.2.2, 실제 디바이스: 컴퓨터 IP
  static const String baseUrl = 'http://192.168.219.102:8000'; // 실제 IP로 변경
  static const String wsUrl = 'ws://192.168.219.102:8000';

  // 타임아웃 설정
  static const int connectionTimeout = 60; // seconds
  static const int receiveTimeout = 100; // seconds
}