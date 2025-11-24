// lib/models/learning_models.dart (새 파일)
class LearningPhase {
  static const String HOME = "home";
  static const String QUESTION_INPUT = "question_input";
  static const String KNOWLEDGE_CHECK = "knowledge_check";
  static const String FIRST_EXPLANATION = "first_explanation";
  static const String SELF_REFLECTION_1 = "self_reflection_1";
  static const String AI_EXPLANATION = "ai_explanation";
  static const String SECOND_EXPLANATION = "second_explanation";
  static const String SELF_REFLECTION_2 = "self_reflection_2";
  static const String EVALUATION = "evaluation";
}

class PhaseInfo {
  final String phase;
  final String instruction;
  final String title;
  final bool canGoBack;
  
  PhaseInfo({
    required this.phase,
    required this.instruction,
    required this.title,
    required this.canGoBack,
  });
  
  factory PhaseInfo.fromJson(Map<String, dynamic> json) {
    return PhaseInfo(
      phase: json['phase'],
      instruction: json['instruction'] ?? '',
      title: json['title'] ?? '',
      canGoBack: json['can_go_back'] ?? false,
    );
  }
}