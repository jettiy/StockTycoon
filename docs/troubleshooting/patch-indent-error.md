# Patch 도구 들여쓰기 꼬임 에러 대처법

## 에러 증상
```
SCRIPT ERROR: Parse Error: Expected statement, found "Indent" instead.
```
GDScript 파일의 들여쓰기(indent)가 꼬였을 때 발생.

## 원인
- 서브에이전트(delegate_task)가 patch로 대규모 코드 교체 시,
  기존 들여쓰기 단계(tab 수)와 새 코드의 들여쓰기 단계가 다른 경우
- 특히 `_make_dice_panel` → `_make_dice_view` 교체 시
  호출부의 `\t` 1단계가 `\t\t` 2단계로 늘어나는 문제
- 함수 정의 중복 (patch 적용 시 old_string이 정확히 매칭되지 않아
  기존 함수가 남고 새 함수가 추가됨)

## 해결 방법

### 1. 에러 라인 확인
에러 메시지에서 라인 번호 확인 (예: `MainGame.gd:5230`)
```
에러 라인 근처를 읽고 들여쓰기가 비정상적인지 확인
```

### 2. Python으로 일괄 수정
```python
with open('scripts/MainGame.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

fixed = []
skip_lines = {5360, 5732}  # 삭제할 라인 번호 (1-indexed)

for i, line in enumerate(lines):
    lineno = i + 1

    if lineno in skip_lines:
        continue

    # 특정 구간에서 한 단계 들여쓰기 제거
    if 5361 <= lineno <= 5733 and line.startswith('\t'):
        fixed.append(line[1:])  # 선행 탭 하나 제거
    else:
        fixed.append(line)

with open('scripts/MainGame.gd', 'w', encoding='utf-8') as f:
    f.writelines(fixed)
```

### 3. 검증
```
python -c "파일 읽고 repr()로 들여c어기 확인"
헤드리스 테스트: godot --headless --quit-after 5
```

## 예방법
- 서브에이전트에 대규모 코드 교체(patch) 지시 시,
  **반드시 기존 코드의 들여쓰기 단계를 명시**
- patch 적용 후 헤드리스 테스트 필수
- GDScript는 들여쓰기가 문법이므로 tab/space 혼용 절대 금지
  (이 프로젝트는 tab 사용)

## 관련 함정
- `Dictionary.get()` + `:=` → Variant 에러 (명시적 타입 사용)
- CanvasLayer `find_child(owned=false)`
- `.0f` 미지원
- `try/catch` 없음
