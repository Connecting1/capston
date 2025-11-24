# backend/test_connection.py
import requests

# 1. 서버 연결 확인
try:
    response = requests.get("http://localhost:8000/")
    print(f"서버 상태: {response.status_code}")
    print(f"응답: {response.json()}")
except Exception as e:
    print(f"서버 연결 실패: {e}")

# 2. API 문서 확인
try:
    response = requests.get("http://localhost:8000/docs")
    print(f"API 문서 상태: {response.status_code}")
except Exception as e:
    print(f"API 문서 접근 실패: {e}")

# 3. 채팅방 생성 디버그
try:
    response = requests.post(
        "http://localhost:8000/api/rooms",
        json={"title": "테스트"},
        headers={"Content-Type": "application/json"}
    )
    print(f"채팅방 생성 상태 코드: {response.status_code}")
    print(f"응답 헤더: {response.headers}")
    print(f"응답 내용: {response.text}")
    if response.status_code == 200:
        print(f"JSON: {response.json()}")
except Exception as e:
    print(f"채팅방 생성 실패: {e}")