# backend/rag_system.py
import chromadb
from chromadb.config import Settings
from sentence_transformers import SentenceTransformer
import PyPDF2
from typing import List, Dict
import os

class RAGSystem:
    """ChromaDB 기반 RAG 시스템"""
    
    def __init__(self):
        # ChromaDB 클라이언트 초기화
        self.client = chromadb.Client(Settings(
            persist_directory="./chroma_db",
            anonymized_telemetry=False
        ))
        
        # 임베딩 모델 초기화
        self.embedding_model = SentenceTransformer('all-MiniLM-L6-v2')
        
        print("✅ RAG 시스템 초기화 완료")
    
    def get_or_create_collection(self, room_id: str):
        """채팅방별 컬렉션 가져오기/생성"""
        collection_name = f"room_{room_id}"
        try:
            collection = self.client.get_collection(collection_name)
        except:
            collection = self.client.create_collection(collection_name)
        return collection
    
    def extract_text_from_pdf(self, pdf_path: str) -> List[Dict[str, str]]:
        """PDF에서 텍스트 추출 (페이지별)"""
        chunks = []
        
        with open(pdf_path, 'rb') as file:
            pdf_reader = PyPDF2.PdfReader(file)
            
            for page_num, page in enumerate(pdf_reader.pages):
                text = page.extract_text()
                
                if text.strip():
                    chunks.append({
                        'text': text,
                        'page': page_num + 1,
                        'metadata': f'Page {page_num + 1}'
                    })
        
        print(f"📄 PDF에서 {len(chunks)}개 페이지 추출 완료")
        return chunks
    
    def add_pdf_to_collection(self, room_id: str, pdf_path: str) -> bool:
        """PDF 내용을 ChromaDB에 저장"""
        try:
            collection = self.get_or_create_collection(room_id)
            
            # PDF 텍스트 추출
            chunks = self.extract_text_from_pdf(pdf_path)
            
            if not chunks:
                print("❌ PDF에서 텍스트를 추출할 수 없습니다")
                return False
            
            # ChromaDB에 저장
            for i, chunk in enumerate(chunks):
                collection.add(
                    documents=[chunk['text']],
                    metadatas=[{'page': chunk['page']}],
                    ids=[f"{room_id}_page_{chunk['page']}"]
                )
            
            print(f"✅ {len(chunks)}개 청크를 ChromaDB에 저장 완료")
            return True
            
        except Exception as e:
            print(f"❌ PDF 저장 오류: {e}")
            return False
    
    def search(self, room_id: str, query: str, n_results: int = 3) -> List[Dict]:
        """질문과 관련된 내용 검색"""
        try:
            collection = self.get_or_create_collection(room_id)
            
            # 컬렉션이 비어있는지 확인
            if collection.count() == 0:
                return []
            
            results = collection.query(
                query_texts=[query],
                n_results=n_results
            )
            
            # 결과 포맷팅
            contexts = []
            if results['documents'] and results['documents'][0]:
                for i, doc in enumerate(results['documents'][0]):
                    metadata = results['metadatas'][0][i] if results['metadatas'] else {}
                    contexts.append({
                        'content': doc,
                        'page': metadata.get('page', 'Unknown')
                    })
            
            print(f"🔍 {len(contexts)}개 관련 내용 검색됨")
            return contexts
            
        except Exception as e:
            print(f"❌ 검색 오류: {e}")
            return []
    
    def has_pdf(self, room_id: str) -> bool:
        """채팅방에 PDF가 업로드되어 있는지 확인"""
        try:
            collection = self.get_or_create_collection(room_id)
            return collection.count() > 0
        except:
            return False

# 전역 인스턴스
rag_system = RAGSystem()