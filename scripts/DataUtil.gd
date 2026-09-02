class_name DataUtil
extends RefCounted

## JSON 파일을 로드하여 Dictionary/Array를 반환합니다.
## 파일이 없거나 파싱에 실패하면 null을 반환합니다.
static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)
