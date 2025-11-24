# backend/models.py
from sqlalchemy import Column, String, Text, DateTime, ForeignKey, Integer, Boolean
from sqlalchemy.orm import relationship
from database import Base
from datetime import datetime
import uuid

class ChatRoom(Base):
    __tablename__ = "chat_rooms"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    title = Column(String(200), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    learning_phase = Column(String(50), default="home")
    current_concept = Column(String(500), nullable=True)
    knowledge_level = Column(Integer, default=0)
    has_pdf = Column(Boolean, default=False)
    
    messages = relationship("Message", back_populates="room", cascade="all, delete-orphan")

class Message(Base):
    __tablename__ = "messages"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    room_id = Column(String, ForeignKey("chat_rooms.id"))
    role = Column(String(50))  # user or assistant
    content = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)

    #파인만 학습 필드
    phase = Column(String(50), nullable=True)
    is_explanation = Column(Boolean, default=False)

    room = relationship("ChatRoom", back_populates="messages")