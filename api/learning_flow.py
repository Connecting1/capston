# backend/learning_flow.py (새 파일)
from typing import Optional
from feynman_prompts import LearningPhase

class LearningFlowManager:
    """학습 흐름 관리"""
    
    # 단계 전환 규칙
    PHASE_TRANSITIONS = {
        LearningPhase.HOME: LearningPhase.QUESTION_INPUT,
        LearningPhase.QUESTION_INPUT: LearningPhase.KNOWLEDGE_CHECK,
        LearningPhase.KNOWLEDGE_CHECK: {
            "knows": LearningPhase.FIRST_EXPLANATION,
            "doesnt_know": LearningPhase.AI_EXPLANATION
        },
        LearningPhase.FIRST_EXPLANATION: LearningPhase.SELF_REFLECTION_1,
        LearningPhase.SELF_REFLECTION_1: LearningPhase.AI_EXPLANATION,
        LearningPhase.AI_EXPLANATION: LearningPhase.SECOND_EXPLANATION,
        LearningPhase.SECOND_EXPLANATION: LearningPhase.SELF_REFLECTION_2,
        LearningPhase.SELF_REFLECTION_2: LearningPhase.EVALUATION,
        LearningPhase.EVALUATION: {
            "retry": LearningPhase.SECOND_EXPLANATION,
            "complete": LearningPhase.HOME
        }
    }
    
    def get_next_phase(
        self, 
        current_phase: LearningPhase, 
        user_choice: Optional[str] = None
    ) -> LearningPhase:
        """다음 학습 단계 반환"""
        
        transition = self.PHASE_TRANSITIONS.get(current_phase)
        
        if isinstance(transition, dict):
            # 사용자 선택에 따른 분기
            return transition.get(user_choice, current_phase)
        elif transition:
            return transition
        else:
            return current_phase
    
    def can_go_back(self, current_phase: LearningPhase) -> bool:
        """이전 단계로 돌아갈 수 있는지 확인"""
        # 평가와 홈에서는 뒤로가기 불가
        return current_phase not in [LearningPhase.HOME, LearningPhase.EVALUATION]
    
    def get_phase_title(self, phase: LearningPhase) -> str:
        """단계별 제목 반환"""
        titles = {
            LearningPhase.HOME: "홈",
            LearningPhase.QUESTION_INPUT: "질문 입력",
            LearningPhase.KNOWLEDGE_CHECK: "지식 수준 확인",
            LearningPhase.FIRST_EXPLANATION: "첫 번째 설명",
            LearningPhase.SELF_REFLECTION_1: "자기 성찰",
            LearningPhase.AI_EXPLANATION: "AI 설명",
            LearningPhase.SECOND_EXPLANATION: "두 번째 설명",
            LearningPhase.SELF_REFLECTION_2: "자기 성찰",
            LearningPhase.EVALUATION: "종합 평가"
        }
        return titles.get(phase, "")
    
    def get_phase_instruction(self, phase: LearningPhase) -> str:
        """단계별 지시문 반환"""
        instructions = {
            LearningPhase.KNOWLEDGE_CHECK: "물어보신 질문에 대한 개념을 어느정도 알고 계시나요?",
            LearningPhase.FIRST_EXPLANATION: "알고 있는 곳까지 해당 개념에 대하여 설명해주세요",
            LearningPhase.SELF_REFLECTION_1: "설명을 하며 모르거나 막혔던 부분에 대해 생각해보고 객관적으로 설명해주세요",
            LearningPhase.SECOND_EXPLANATION: "이해하신 개념, 지식에 대한 설명을 해주세요",
            LearningPhase.SELF_REFLECTION_2: "설명을 하며 모르거나 막혔던 부분에 대해 생각해보고 객관적으로 설명해주세요",
        }
        return instructions.get(phase, "")

flow_manager = LearningFlowManager()