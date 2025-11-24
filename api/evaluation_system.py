# backend/evaluation_system.py (새 파일)
from typing import Dict, List, Optional
import re

class FeynmanEvaluator:
    """파인만 학습법 평가 시스템"""
    
    def analyze_explanation(self, explanation: str) -> Dict:
        """사용자 설명 분석"""
        
        analysis = {
            "understanding": self._analyze_understanding(explanation),
            "expression": self._analyze_expression(explanation),
            "application": self._analyze_application(explanation),
            "metacognition": self._analyze_metacognition(explanation),
            "knowledge_level": self._analyze_knowledge_level(explanation)
        }
        
        return analysis
    
    def _analyze_understanding(self, text: str) -> Dict:
        """이해도 분석"""
        indicators = {
            "clear_concepts": self._count_clear_concepts(text),
            "confusion_markers": self._find_confusion_markers(text),
            "coherence": self._check_coherence(text)
        }
        
        return {
            "level": self._determine_understanding_level(indicators),
            "details": indicators
        }
    
    def _analyze_expression(self, text: str) -> Dict:
        """표현력 분석"""
        
        # 전문 용어 감지
        technical_terms = self._detect_technical_terms(text)
        
        # 비유/예시 사용
        analogies = self._find_analogies(text)
        
        # 문장 복잡도
        complexity = self._calculate_complexity(text)
        
        return {
            "technical_terms": technical_terms,
            "analogies_count": len(analogies),
            "complexity": complexity,
            "suggestions": self._generate_expression_suggestions(technical_terms, complexity)
        }
    
    def _detect_technical_terms(self, text: str) -> List[str]:
        """전문 용어 감지"""
        # 실제로는 더 정교한 NLP 처리 필요
        technical_patterns = [
            r'\b[A-Z]{2,}\b',  # 약어
            r'\b\w+tion\b',    # -tion으로 끝나는 단어
            r'\b\w+ity\b',     # -ity로 끝나는 단어
        ]
        
        found_terms = []
        for pattern in technical_patterns:
            matches = re.findall(pattern, text)
            found_terms.extend(matches)
        
        return list(set(found_terms))
    
    def _find_analogies(self, text: str) -> List[str]:
        """비유 표현 찾기"""
        analogy_markers = ['처럼', '같이', '마치', '예를 들어', '비유하자면']
        analogies = []
        
        for marker in analogy_markers:
            if marker in text:
                # 마커 주변 문장 추출
                sentences = text.split('.')
                for sent in sentences:
                    if marker in sent:
                        analogies.append(sent.strip())
        
        return analogies
    
    def _calculate_complexity(self, text: str) -> str:
        """문장 복잡도 계산"""
        sentences = text.split('.')
        avg_length = sum(len(s.split()) for s in sentences) / max(len(sentences), 1)
        
        if avg_length < 10:
            return "simple"
        elif avg_length < 20:
            return "moderate"
        else:
            return "complex"
    
    def _generate_expression_suggestions(self, technical_terms: List[str], complexity: str) -> List[str]:
        """표현 개선 제안"""
        suggestions = []
        
        if technical_terms:
            suggestions.append(f"다음 전문 용어를 더 쉬운 말로 바꿔보세요: {', '.join(technical_terms[:3])}")
        
        if complexity == "complex":
            suggestions.append("문장을 더 짧고 간단하게 나누어 설명해보세요")
        
        if complexity == "simple":
            suggestions.append("조금 더 구체적인 설명을 추가해보세요")
        
        return suggestions
    
    def generate_feedback(self, analysis: Dict, phase: str) -> str:
        """종합 피드백 생성"""
        
        feedback = []
        
        # 이해도 피드백
        understanding = analysis.get("understanding", {})
        feedback.append(f"**이해도**\n{self._generate_understanding_feedback(understanding)}")
        
        # 표현력 피드백
        expression = analysis.get("expression", {})
        feedback.append(f"**표현력**\n{self._generate_expression_feedback(expression)}")
        
        # 추가 피드백들...
        
        return "\n\n".join(feedback)
    
    def _generate_understanding_feedback(self, understanding: Dict) -> str:
        """이해도 피드백 생성"""
        level = understanding.get("level", "unknown")
        
        if level == "high":
            return "핵심 개념을 잘 이해하고 계십니다. 세부 사항까지 명확하게 파악하고 있어요."
        elif level == "medium":
            return "기본 개념은 이해하고 있으나, 일부 세부 사항에서 보완이 필요합니다."
        else:
            return "개념의 기초부터 차근차근 다시 학습해보시면 좋겠습니다."
    
    def _generate_expression_feedback(self, expression: Dict) -> str:
        """표현력 피드백 생성"""
        suggestions = expression.get("suggestions", [])
        
        feedback = "설명 방식에 대한 피드백입니다:\n"
        
        if expression.get("analogies_count", 0) > 0:
            feedback += "- 비유를 잘 활용하여 이해하기 쉽게 설명했습니다.\n"
        else:
            feedback += "- 일상적인 비유나 예시를 추가하면 더 이해하기 쉬울 것 같습니다.\n"
        
        for suggestion in suggestions:
            feedback += f"- {suggestion}\n"
        
        return feedback
    
    # 헬퍼 메서드들
    def _count_clear_concepts(self, text: str) -> int:
        """명확한 개념 설명 수 계산"""
        # 구현 필요
        return 0
    
    def _find_confusion_markers(self, text: str) -> List[str]:
        """혼란 지표 찾기"""
        markers = ['잘 모르겠', '확실하지 않', '아마도', '것 같습니다']
        found = [m for m in markers if m in text]
        return found
    
    def _check_coherence(self, text: str) -> float:
        """논리적 일관성 체크"""
        # 실제로는 더 복잡한 NLP 처리 필요
        return 0.7
    
    def _determine_understanding_level(self, indicators: Dict) -> str:
        """이해 수준 결정"""
        if indicators.get("confusion_markers", []):
            return "low"
        elif indicators.get("coherence", 0) > 0.8:
            return "high"
        else:
            return "medium"
    
    def _analyze_application(self, text: str) -> Dict:
        """응용력 분석"""
        return {"level": "moderate", "details": {}}
    
    def _analyze_metacognition(self, text: str) -> Dict:
        """메타인지 분석"""
        return {"level": "developing", "details": {}}
    
    def _analyze_knowledge_level(self, text: str) -> Dict:
        """배경 지식 수준 분석"""
        return {"level": "intermediate", "details": {}}

evaluator = FeynmanEvaluator()