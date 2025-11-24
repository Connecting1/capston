from langchain_community.llms import Ollama
from langchain.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
import sys

#프롬프트 템플릿 생성(가장 단순한 형태의 프롬프트 형식 - 요구사항을 적으면 됨)
prompt = ChatPromptTemplate.from_template(
    "당신은 유능한 이아림입니다. 다음 질문에 답해주세요. <질문> : {question}"
)

# Ollama 연결 (local에서 실행 중인 Ollama와 연결)
# temperature = 0 : AI에게 최대한 정확한 답변을 요구하는 것이다.(1에 가까울수록 AI가 창의적, 예측X 답변)
llm = Ollama(temperature = 0, model = "llama3.1:8b")

## invoke 형식의 답변 ##
# chain 실행(ollama 에게 질문을 던지는 것)
# invoke 형식 : 한번에 대답 처리 / 단일 처리
# response = llm.invoke("세계에서 가장 붐비는 항공 노선은 어디인가?")

# 결과 출력(ollama의 응답을 출력하며 한번에 출력된다)
#print(response)

## stream 형식의 답변 ##
# stream 형식 : 응답 생성 시 바로 토큰 단위로 실시간 수신 - GPT 방식

# question = "세계에서 가장 붐비는 항공 노선 4개를 알려줘" # 나중에 질문이 flutter UI 통해 입력되는 방식 구현x

# AI에게 프롬프트를 채팅을 통해 설정하는 것.(질문과 같이 플러스해서) = 사실상 채팅을 통해 요구사항을 말하는 것
#summary_query = f"""
#    아래 질문에 대한 대답을 할 때 IATA 자료를 참고해. 대답은 아래 형식으로 만들어줘. 마지막에는 출처를 적어줘.
#    형식 : 
#    1. 대답 1
#    2. 대답 2

#    질문 : {question}
#    """

    
# 스트리밍 출력(chunk는 Ollama가 생성하는 토큰을 저장하는 변수)
#for chunk in llm.stream(summary_query):
#    sys.stdout.write(chunk) # 콘솔에 출력하는 함수(줄바꿈 자동 X)
#    sys.stdout.flush() # flush : 강제로 버퍼를 출력하는 명령어(바로바로)

#print() # 줄바꿈 처리

### 스트림 출력 파서 생성 ###
# OutputParser 개념 : AI 모델의 응답 결과를 사람이 이해 할 수 있는 형식으로 변화 시켜주는 것.
# StrOutputParser : 문자열 형식으로 변화시켜 AI 모델의 응답을 반환해주는 Parser.
class CustomStreamOutputParser(StrOutputParser):
    def parse(self, text):
        return text
    
output_parser = CustomStreamOutputParser() #만든 클래스의 객체 생성

# chain 연결(LCEL 구현) : Langchain의 도구들을 연결해주는 기능 = LECL(프롬프트 - 모델 - 출력방식)
### LCEL 연결 가능 요소 ###
# 1. Prompt Template 
# 2. LLM/Chatmodel
# 3. OutputParser
# 4. Tool(계산기, 웹 검색 등)
# 5. RunnableLambda / RunnableMap : 체인 중간에서 값 가공 또는 흐름 제어
# 6. DocumentLoader / Retriver : RAG 에서 문서 검색
# 7. Memory : 대화 히스토리 기억 및 반영
chain = prompt | llm | output_parser

# chain 실행 및 결과 출력
for chunk in chain.stream({"question": "이아림에 대해 맞춰보세세요."}):
    print(chunk, end = "", flush = True)

