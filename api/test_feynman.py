import requests
import json

base_url = "http://localhost:8000"

# 1. 채팅방 생성
print("1. 채팅방 생성...")
response = requests.post(f"{base_url}/api/rooms", json={"title": "파인만 테스트"})
room = response.json()
room_id = room["id"]
print(f"✓ 채팅방 생성됨: {room_id}")

# 2. 현재 학습 단계 확인
print("\n2. 현재 학습 단계 확인...")
response = requests.get(f"{base_url}/api/learning/phase/{room_id}")
phase_info = response.json()
print(f"✓ 현재 단계: {phase_info}")

# 3. 단계 전환 테스트 (knows 선택)
print("\n3. 단계 전환 테스트...")
response = requests.post(
    f"{base_url}/api/learning/transition",
    json={
        "room_id": room_id,
        "user_choice": "knows"
    }
)
if response.status_code == 200:
    transition = response.json()
    print(f"✓ 단계 전환 성공: {transition}")
else:
    print(f"✗ 에러: {response.status_code} - {response.text}")

print("\n테스트 완료!")