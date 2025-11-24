# backend/server.py (수정 버전)
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Depends, HTTPException, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from typing import List, Optional, Dict
from database import engine, get_db, SessionLocal
from pydantic import BaseModel
from datetime import datetime
import httpx
import json
import models
import socket
import asyncio
import os

# 새로운 모듈 import
from feynman_prompts import LearningPhase, feynman_engine
from evaluation_system import evaluator
from learning_flow import flow_manager
#Rag 시스템 
from rag_system import rag_system
import shutil

# 데이터베이스 테이블 생성
models.Base.metadata.create_all(bind=engine)

app = FastAPI()

# uploads 폴더 생성
os.makedirs("uploads", exist_ok=True)

# 실제 IP 주소 확인
def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
    finally:
        s.close()
    return ip

LOCAL_IP = get_local_ip()
print(f"Server IP: {LOCAL_IP}:8000")

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ========== 기존 Pydantic 모델 ==========
class ChatRoomCreate(BaseModel):
    title: str

class MessageResponse(BaseModel):
    id: str
    role: str
    content: str
    created_at: datetime
    
    class Config:
        orm_mode = True

class ChatRoomResponse(BaseModel):
    id: str
    title: str
    created_at: datetime
    updated_at: datetime
    
    class Config:
        orm_mode = True

class MessageCreate(BaseModel):
    content: str
    role: str
    phase: str

# ========== 새로운 Pydantic 모델 (파인만) ==========
class PhaseTransitionRequest(BaseModel):
    room_id: str
    user_choice: Optional[str] = None
    message: Optional[str] = None

class PhaseResponse(BaseModel):
    current_phase: str
    next_phase: str
    instruction: str
    title: str

# ========== 키워드 추출 함수 (새로 추가) ==========
async def extract_concept_keyword(user_message: str) -> str:
    """사용자 질문에서 핵심 개념 키워드 추출"""
    
    extraction_prompt = f"""다음 질문에서 학습하고자 하는 핵심 개념/키워드만 추출하세요.
질문: {user_message}

규칙:
- 2-3단어 이내의 핵심 개념만 추출
- "에 대해", "알려줘", "설명해줘" 등은 제외
- 명사형으로 추출
- 한 줄로만 답변

예시:
질문: "자료구조에 대해서 알려줘" → 자료구조
질문: "머신러닝 알고리즘 설명해줘" → 머신러닝 알고리즘
질문: "양자역학이 뭐야?" → 양자역학

키워드:"""

    try:
        async with httpx.AsyncClient() as client:
            print(f"🔍 키워드 추출 중: '{user_message}'")
            response = await client.post(
                "http://localhost:11434/api/generate",
                json={
                    "model": "llama3.1:8b",
                    "prompt": extraction_prompt,
                    "stream": False
                },
                timeout=180.0
            )
            
            if response.status_code == 200:
                result = response.json()
                keyword = result.get("response", "").strip()
                # 첫 줄만 가져오기 (추가 설명 제거)
                keyword = keyword.split('\n')[0].strip()
                # 따옴표 제거
                keyword = keyword.strip('"\'')
                print(f"✅ 추출된 키워드: '{keyword}'")
                return keyword if keyword else user_message
            else:
                print(f"⚠️ 키워드 추출 실패 (상태: {response.status_code}), 원본 사용")
                return user_message
    except Exception as e:
        print(f"⚠️ 키워드 추출 오류: {e}, 원본 사용")
        return user_message

# ========== 기존 엔드포인트 유지 ==========
@app.get("/")
async def root():
    return {"message": "Backend is running", "ip": LOCAL_IP}

@app.get("/test-ollama")
async def test_ollama():
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "http://localhost:11434/api/generate",
                json={
                    "model": "llama3.1:8b",
                    "prompt": "Say hello in Korean",
                    "stream": False
                },
                timeout=30.0
            )
            
            if response.status_code == 200:
                return {"status": "success", "response": response.json()}
            else:
                return {"status": "error", "code": response.status_code}
                
    except httpx.ConnectError:
        return {"status": "error", "message": "Cannot connect to Ollama"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.post("/api/rooms", response_model=ChatRoomResponse)
def create_room(room: ChatRoomCreate, db: Session = Depends(get_db)):
    """새 채팅방 생성"""
    db_room = models.ChatRoom(
        title=room.title,
        learning_phase="home"  # 파인만 학습 초기 단계
    )
    db.add(db_room)
    db.commit()
    db.refresh(db_room)
    return db_room

@app.get("/api/rooms", response_model=List[ChatRoomResponse])
def get_rooms(db: Session = Depends(get_db)):
    """모든 채팅방 조회"""
    rooms = db.query(models.ChatRoom).order_by(models.ChatRoom.updated_at.desc()).all()
    return rooms

@app.get("/api/rooms/{room_id}/messages", response_model=List[MessageResponse])
def get_messages(room_id: str, db: Session = Depends(get_db)):
    """특정 채팅방의 메시지 조회"""
    messages = db.query(models.Message).filter(
        models.Message.room_id == room_id
    ).order_by(models.Message.created_at).all()
    return messages

@app.delete("/api/rooms/{room_id}")
def delete_room(room_id: str, db: Session = Depends(get_db)):
    """채팅방 삭제 (메시지도 함께 삭제됨)"""
    room = db.query(models.ChatRoom).filter(models.ChatRoom.id == room_id).first()
    
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    
    # CASCADE 설정 덕분에 메시지들도 자동 삭제됨
    db.delete(room)
    db.commit()
    
    print(f"🗑️ 채팅방 삭제됨: {room_id}")
    
    return {"status": "ok", "message": "Room deleted"}

class DeleteRoomsRequest(BaseModel):
    room_ids: List[str]

@app.post("/api/rooms/delete-multiple")
def delete_multiple_rooms(request: DeleteRoomsRequest, db: Session = Depends(get_db)):
    """여러 채팅방 한 번에 삭제"""
    deleted_count = 0
    
    for room_id in request.room_ids:
        room = db.query(models.ChatRoom).filter(models.ChatRoom.id == room_id).first()
        if room:
            db.delete(room)
            deleted_count += 1
    
    db.commit()
    
    print(f"🗑️ {deleted_count}개 채팅방 삭제됨")
    
    return {"status": "ok", "deleted_count": deleted_count}

@app.post("/api/rooms/{room_id}/messages")
def save_message(room_id: str, message: MessageCreate, db: Session = Depends(get_db)):
    """단순 메시지 저장 (AI 응답 없이)"""
    room = db.query(models.ChatRoom).filter(models.ChatRoom.id == room_id).first()
    
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    
    # 메시지 저장
    db_message = models.Message(
        room_id=room_id,
        role=message.role,
        content=message.content,
        phase=message.phase
    )
    db.add(db_message)
    
    # 방 업데이트 시간 갱신
    room.updated_at = datetime.utcnow()
    db.commit()
    
    print(f"💾 메시지 저장됨 (단계: {message.phase}): {message.content[:50]}...")
    
    return {"status": "ok", "message_id": db_message.id}

# ========== 새로운 파인만 학습 엔드포인트 ==========
@app.post("/api/learning/transition", response_model=PhaseResponse)
async def transition_phase(
    request: PhaseTransitionRequest,
    db: Session = Depends(get_db)
):
    """학습 단계 전환"""
    room = db.query(models.ChatRoom).filter(
        models.ChatRoom.id == request.room_id
    ).first()
    
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    
    # 현재 단계 가져오기
    current_phase = LearningPhase(room.learning_phase or "home")
    
    # 다음 단계 결정
    next_phase = flow_manager.get_next_phase(current_phase, request.user_choice)
    
    # DB 업데이트
    room.learning_phase = next_phase.value
    db.commit()
    
    return PhaseResponse(
        current_phase=current_phase.value,
        next_phase=next_phase.value,
        instruction=flow_manager.get_phase_instruction(next_phase),
        title=flow_manager.get_phase_title(next_phase)
    )

@app.get("/api/learning/phase/{room_id}")
async def get_current_phase(room_id: str, db: Session = Depends(get_db)):
    """현재 학습 단계 조회"""
    room = db.query(models.ChatRoom).filter(
        models.ChatRoom.id == room_id
    ).first()
    
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    
    phase = LearningPhase(room.learning_phase or "home")
    
    return {
        "phase": phase.value,
        "instruction": flow_manager.get_phase_instruction(phase),
        "title": flow_manager.get_phase_title(phase),
        "can_go_back": flow_manager.can_go_back(phase)
    }

@app.post("/api/rooms/{room_id}/upload-pdf")
async def upload_pdf(
    room_id: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """PDF 파일 업로드 및 RAG 시스템에 등록"""
    
    # 파일 형식 확인
    if not file.filename.endswith('.pdf'):
        raise HTTPException(status_code=400, detail="PDF 파일만 업로드 가능합니다")
    
    # 파일 크기 확인 (10MB 제한)
    file_size = 0
    chunk_size = 1024 * 1024  # 1MB
    temp_file = f"uploads/temp_{room_id}.pdf"
    
    try:
        with open(temp_file, "wb") as buffer:
            while chunk := await file.read(chunk_size):
                file_size += len(chunk)
                if file_size > 10 * 1024 * 1024:  # 10MB
                    os.remove(temp_file)
                    raise HTTPException(status_code=400, detail="파일 크기는 10MB 이하여야 합니다")
                buffer.write(chunk)
        
        # RAG 시스템에 PDF 추가
        success = rag_system.add_pdf_to_collection(room_id, temp_file)
        
        if success:
            # DB 업데이트
            room = db.query(models.ChatRoom).filter(models.ChatRoom.id == room_id).first()
            if room:
                room.has_pdf = True
                db.commit()
            
            print(f"✅ PDF 업로드 성공: {file.filename} (Room: {room_id})")
            return {"status": "success", "message": "PDF 업로드 완료"}
        else:
            raise HTTPException(status_code=500, detail="PDF 처리 실패")
            
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ PDF 업로드 오류: {e}")
        raise HTTPException(status_code=500, detail=f"업로드 실패: {str(e)}")
    finally:
        # 임시 파일 삭제
        if os.path.exists(temp_file):
            os.remove(temp_file)

# ========== 수정된 WebSocket (파인만 통합) ==========
@app.websocket("/ws/chat/{room_id}")
async def websocket_endpoint_with_feynman(
    websocket: WebSocket, 
    room_id: str
):
    await websocket.accept()
    print(f"✅ WebSocket 연결됨 (Room: {room_id})")

    db = SessionLocal()
    
    try:
        room = db.query(models.ChatRoom).filter(models.ChatRoom.id == room_id).first()
        if not room:
            await websocket.send_json({"error": "Room not found"})
            await websocket.close()
            return
        
        while True:
            data = await websocket.receive_text()
            print(f"📥 받은 메시지 (Room {room_id}): {data}")
            
            message_data = json.loads(data)
            
            # 메시지 타입 확인
            msg_type = message_data.get("type", "message")
            
            if msg_type == "phase_transition":
                # 단계 전환 요청
                user_choice = message_data.get("choice")
                current_phase = LearningPhase(room.learning_phase or "home")
                next_phase = flow_manager.get_next_phase(current_phase, user_choice)
                
                room.learning_phase = next_phase.value
                db.commit()
                
                await websocket.send_json({
                    "type": "phase_changed",
                    "phase": next_phase.value,
                    "instruction": flow_manager.get_phase_instruction(next_phase),
                    "title": flow_manager.get_phase_title(next_phase)
                })
                continue
            
            # 일반 메시지 처리
            try:
                user_message = message_data["message"]
            except KeyError as e:
                await websocket.send_json({
                    "type": "error",
                    "content": "Invalid message format"
                })
                continue

            # RAG 컨텍스트 검색 (추가)
            rag_context = ""
            if rag_system.has_pdf(room_id):
                contexts = rag_system.search(room_id, user_message, n_results=5)
                if contexts:
                    rag_context = "\n\n**참고 자료:**\n"
                    for ctx in contexts:
                        rag_context += f"[Page {ctx['page']}] {ctx['content'][:200]}...\n\n"
                    print(f"📚 RAG 컨텍스트 추가됨 ({len(contexts)}개)")
            
            # 현재 학습 단계 확인
            db.refresh(room)  # DB 
            current_phase = LearningPhase(room.learning_phase or "home")
            
            # 사용자 메시지 저장 (단계 정보 포함)
            user_msg = models.Message(
                room_id=room_id,
                role="user",
                content=user_message,
                phase=current_phase.value if hasattr(models.Message, 'phase') else None,
                is_explanation=(current_phase in [
                    LearningPhase.FIRST_EXPLANATION,
                    LearningPhase.SECOND_EXPLANATION
                ]) if hasattr(models.Message, 'is_explanation') else None
            )
            db.add(user_msg)
            db.commit()
            print(f"💾 사용자 메시지 저장됨 (단계: {current_phase.value})")
            
            if current_phase == LearningPhase.HOME:
                # 키워드 추출
                concept_keyword = await extract_concept_keyword(user_message)

                # 개념 저장
                room.current_concept = user_message
                room.learning_phase = LearningPhase.KNOWLEDGE_CHECK.value
                db.commit()
    
                print(f"💾 개념 저장: '{concept_keyword}'")
                print(f"🔄 단계 전환: HOME → KNOWLEDGE_CHECK")
    
            # AI 응답 없이 바로 단계 전환 알림
                await websocket.send_json({
                    "type": "phase_changed",
                    "phase": LearningPhase.KNOWLEDGE_CHECK.value,
                    "instruction": flow_manager.get_phase_instruction(LearningPhase.KNOWLEDGE_CHECK),
                    "title": flow_manager.get_phase_title(LearningPhase.KNOWLEDGE_CHECK)
                })
    
                # 단순 안내 메시지만 전송
                simple_response = f"'{concept_keyword}'에 대해 학습하시는군요! 이 개념에 대해 얼마나 알고 계신가요?"
    
                ai_msg = models.Message(
                    room_id=room_id,
                    role="assistant",
                    content=simple_response,
                    phase=LearningPhase.KNOWLEDGE_CHECK.value if hasattr(models.Message, 'phase') else None
                )
                db.add(ai_msg)
                room.updated_at = datetime.utcnow()
                db.commit()
    
                await websocket.send_json({
                    "type": "stream",
                    "content": simple_response,
                    "phase": LearningPhase.KNOWLEDGE_CHECK.value
                })
    
                await websocket.send_json({
                    "type": "complete",
                    "phase": LearningPhase.KNOWLEDGE_CHECK.value
                })
    
                print("✅ KNOWLEDGE_CHECK 단계로 전환 완료")
                continue  # Ollama 호출 없이 다음 메시지 대기


            # 사용자 설명 분석 (설명 단계인 경우)
            analysis = None
            if current_phase in [LearningPhase.FIRST_EXPLANATION, LearningPhase.SECOND_EXPLANATION]:
                analysis = evaluator.analyze_explanation(user_message)
                print(f"📊 설명 분석 완료")
            
            # 컨텍스트 준비
            context = {
                "concept": room.current_concept if hasattr(room, 'current_concept') else None,
                "knowledge_level": room.knowledge_level if hasattr(room, 'knowledge_level') else 0,
                "analysis": analysis,
                "phase": current_phase.value
            }
            
            # 파인만 프롬프트 가져오기
            system_prompt = feynman_engine.get_prompt_for_phase(current_phase, context)
            
            # Ollama API 호출
            ai_response = ""
            try:
                async with httpx.AsyncClient() as client:
                    print("🤖 Ollama 요청 중 (파인만 모드)...")
                    
                    # Ollama에 시스템 프롬프트 포함
                    if rag_context:
                        full_prompt = f"{system_prompt}\n\n{rag_context}\n\n사용자: {user_message}\n\nAI:"
                    else:
                        full_prompt = f"{system_prompt}\n\n사용자: {user_message}\n\nAI:"
                    print(f"📝 프롬프트 길이: {len(full_prompt)} 문자")
                    print(f"📝 프롬프트 미리보기:\n{full_prompt[:500]}...")
                    
                    async with client.stream(
                        "POST",
                        "http://localhost:11434/api/generate",
                        json={
                            "model": "llama3.1:8b",
                            "prompt": full_prompt,
                            "stream": True
                        },
                        timeout=httpx.Timeout(300.0, connect=60.0)
                    ) as response:
                        
                        print(f"📡 Ollama 응답 상태: {response.status_code}")
                        
                        if response.status_code != 200:
                            await websocket.send_json({
                                "type": "error",
                                "content": f"Ollama error: {response.status_code}"
                            })
                            continue
                        
                        async for line in response.aiter_lines():
                            if line.strip():
                                try:
                                    chunk_data = json.loads(line)
                                    
                                    if "response" in chunk_data:
                                        chunk = chunk_data["response"]
                                        ai_response += chunk
                                        
                                        await websocket.send_json({
                                            "type": "stream",
                                            "content": chunk,
                                            "phase": current_phase.value
                                        })
                                    
                                    if chunk_data.get("done", False):
                                        break
                                        
                                except json.JSONDecodeError:
                                    continue
                
                # AI 응답 저장
                ai_msg = models.Message(
                    room_id=room_id,
                    role="assistant",
                    content=ai_response,
                    phase=current_phase.value if hasattr(models.Message, 'phase') else None
                )
                db.add(ai_msg)
                room.updated_at = datetime.utcnow()
                db.commit()
                print(f"💾 AI 응답 저장됨 (단계: {current_phase.value})")
                
                # 평가 단계인 경우 평가 결과 저장
                if current_phase == LearningPhase.EVALUATION and analysis:
                    if hasattr(models, 'LearningEvaluation'):
                        evaluation = models.LearningEvaluation(
                            room_id=room_id,
                            message_id=user_msg.id,
                            strengths=analysis.get("strengths", []),
                            weaknesses=analysis.get("weaknesses", []),
                            suggestions=analysis.get("suggestions", [])
                        )
                        db.add(evaluation)
                        db.commit()
                        print(f"📊 평가 결과 저장됨")
                
                await websocket.send_json({
                    "type": "complete",
                    "phase": current_phase.value
                })
                print("✉️ 완료 신호 전송")
                
            except Exception as e:
                import traceback
                error_detail = traceback.format_exc()
                print(f"❌ 처리 오류 발생!")
                print(f"❌ 에러 타입: {type(e).__name__}")
                print(f"❌ 에러 메시지: {str(e)}")
                print(f"❌ 상세 스택:")
                print(error_detail)
    
                await websocket.send_json({
                    "type": "error",
                    "content": f"Error: {str(e)}"
                })
                
    except WebSocketDisconnect:
        print(f"🔌 WebSocket 연결 끊김 (Room: {room_id})")
    except Exception as e:
        print(f"❌ WebSocket 오류: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    import uvicorn
    print("="*50)
    print(f"🚀 파인만 학습법 서버 시작")
    print(f"📍 Local IP: http://{LOCAL_IP}:8000")
    print(f"📍 Localhost: http://localhost:8000")
    print(f"🧪 Ollama 테스트: http://localhost:8000/test-ollama")
    print(f"📚 API 문서: http://localhost:8000/docs")
    print("="*50)
    print("📌 학습 API:")
    print(f"  - 현재 단계: GET /api/learning/phase/{{room_id}}")
    print(f"  - 단계 전환: POST /api/learning/transition")
    print("="*50)
    
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")