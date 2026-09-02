#!/usr/bin/env python3
"""Patch: 미니게임 3개(사다리타기, 블랙잭, 주사위대결)의 하드코딩된 Color()를 상수로 치환."""

import difflib
import shutil

FILEPATH = r"C:\Users\USER-PC\Desktop\StockTycoon\scripts\MainGame.gd"
BACKUP = FILEPATH + ".bak"

# ── New constants to insert after line 22 (1-indexed) ──
NEW_CONSTANTS = """\
# 미니게임 공통 색상
const COL_NPC := Color(0.91, 0.11, 0.55, 1)       # #E81C8C — 핑크 (NPC/미니게임 타이틀)
const COL_USER := Color(0.13, 0.78, 0.85, 1)      # #21C7D9 — 시안 (플레이어)
const COL_WIN := Color(0.16, 0.65, 0.42, 1)        # #28A66A — 승리
const COL_LOSE := Color(0.80, 0.27, 0.27, 1)       # #CC4545 — 패배
const COL_TIE := Color(0.85, 0.70, 0.30, 1)        # #D9B34D — 무승부
const COL_CARD_BG := Color(0.15, 0.15, 0.27, 1)    # 블랙잭 카드 배경
const COL_CARD_BORDER := Color(0.25, 0.25, 0.33, 1) # 블랙잭 카드 테두리
const COL_CARD_HIT_BORDER := Color(1.0, 0.28, 0.34, 1) # 블랙잭 히트 카드 테두리
const OVERLAY_ALPHA := 0.75                         # 모든 팝업 오버레이 알파
"""

# ── Replacements: (line_number_1based, old_fragment, new_fragment) ──
# All line numbers are in the ORIGINAL file.
REPLACEMENTS = [
    # ════════ 사다리타기 (3869-4380) ════════
    # 오버레이
    (3889, 'Color(0, 0, 0, 0.75)', 'Color(0, 0, 0, OVERLAY_ALPHA)'),
    # 패널 배경/테두리
    (3901, 'Color(0.13, 0.13, 0.20, 1)', 'COL_PANEL'),
    (3902, 'Color(0.35, 0.35, 0.45, 1)', 'COL_BORDER'),
    # 타이틀 핑크
    (3920, 'Color(0.91, 0.11, 0.55, 1)', 'COL_NPC'),
    # 범례 p_swatch
    (3999, 'Color(0.13, 0.78, 0.85, 1)  # 청록', 'COL_USER  # 시안'),
    # 범례 p_legend_text
    (4006, 'Color(0.13, 0.78, 0.85, 1)', 'COL_USER'),
    # 범례 q_swatch
    (4013, 'Color(0.91, 0.11, 0.55, 1)  # 분홍', 'COL_NPC  # 핑크'),
    # 범례 q_legend_text
    (4020, 'Color(0.91, 0.11, 0.55, 1)', 'COL_NPC'),
    # user_color (ladder choice)
    (4112, 'Color(0.13, 0.78, 0.85, 1)  # 청록 = 플레이어', 'COL_USER  # 시안 = 플레이어'),
    # 애니메이션 색상
    (4189, 'Color("#22C7D8")', 'COL_USER'),
    (4190, 'Color("#FF2FA3")', 'COL_NPC'),
    # line_color
    (4191, 'Color(0.35, 0.35, 0.45, 1)', 'COL_BORDER'),
    # 결과 색상
    (4349, 'Color("#28A66A")', 'COL_WIN'),
    (4352, 'Color("#CC4545")', 'COL_LOSE'),
    # toast 결과 (한 줄에 2개)
    (4367, 'Color("#28A66A")', 'COL_WIN'),
    (4367, 'Color("#CC4545")', 'COL_LOSE'),

    # ════════ 블랙잭 (4384-5047) ════════
    # 오버레이
    (4404, 'Color(0, 0, 0, 0.75)', 'Color(0, 0, 0, OVERLAY_ALPHA)'),
    # 패널 배경/테두리
    (4416, 'Color(0.10, 0.10, 0.18, 1)', 'COL_PANEL'),
    (4417, 'Color(0.35, 0.35, 0.45, 1)', 'COL_BORDER'),
    # 타이틀 핑크
    (4436, 'Color(0.91, 0.11, 0.55, 1)', 'COL_NPC'),
    # user/dealer title, VS label → COL_TEXT_BRIGHT
    (4510, 'Color(0.88, 0.88, 0.92, 1)', 'COL_TEXT_BRIGHT'),
    (4533, 'Color(0.88, 0.88, 0.92, 1)', 'COL_TEXT_BRIGHT'),
    (4548, 'Color(0.88, 0.88, 0.92, 1)', 'COL_TEXT_BRIGHT'),
    # _make_card_panel: face_down bg/border
    (4657, 'Color(0.25, 0.25, 0.33, 1)', 'COL_CARD_BORDER'),
    (4658, 'Color(0.25, 0.25, 0.33, 1)', 'COL_CARD_BORDER'),
    # _make_card_panel: face_up bg/border
    (4660, 'Color(0.15, 0.15, 0.27, 1)', 'COL_CARD_BG'),
    (4661, 'Color(0.25, 0.25, 0.34, 1)', 'COL_CARD_BORDER'),
    # 카드 글자
    (4684, 'Color(0.88, 0.88, 0.92, 1)', 'COL_TEXT_BRIGHT'),
    # flip: bg/border
    (4923, 'Color(0.15, 0.15, 0.27, 1)', 'COL_CARD_BG'),
    (4924, 'Color(0.25, 0.25, 0.34, 1)', 'COL_CARD_BORDER'),
    # hit border (bust)
    (4931, 'Color(1.0, 0.28, 0.34, 1)', 'COL_CARD_HIT_BORDER'),
    # 결과 승리/패배
    (4977, 'Color(0.18, 0.65, 0.35, 1)', 'COL_WIN'),
    (4983, 'Color(0.80, 0.20, 0.20, 1)', 'COL_LOSE'),

    # ════════ 주사위대결 (5048-5628) ════════
    # 오버레이
    (5067, 'Color(0, 0, 0, 0.75)', 'Color(0, 0, 0, OVERLAY_ALPHA)'),
    # 패널 배경/테두리
    (5079, 'Color(0.10, 0.10, 0.18, 1)', 'COL_PANEL'),
    (5080, 'Color(0.35, 0.35, 0.45, 1)', 'COL_BORDER'),
    # 타이틀 핑크
    (5099, 'Color(0.91, 0.11, 0.55, 1)', 'COL_NPC'),
    # user_title
    (5173, 'Color(0.13, 0.75, 0.63, 1)', 'COL_USER'),
    # user_dice
    (5181, 'Color(0.13, 0.78, 0.85, 1)', 'COL_USER'),
    (5186, 'Color(0.13, 0.78, 0.85, 1)', 'COL_USER'),
    # VS label
    (5208, 'Color(0.88, 0.88, 0.92, 1)', 'COL_TEXT_BRIGHT'),
    # npc_title
    (5223, 'Color(0.0, 0.74, 0.83, 1)', 'COL_NPC'),
    # npc_dice
    (5231, 'Color(0.0, 0.74, 0.83, 1)', 'COL_NPC'),
    (5236, 'Color(0.0, 0.74, 0.83, 1)', 'COL_NPC'),
    # settle: win_col, lose_col, tie_col
    (5522, 'Color(0.13, 0.75, 0.63, 1)', 'COL_USER'),
    (5523, 'Color(1.0, 0.278, 0.341, 1)', 'COL_LOSE'),
    (5524, 'Color(1.0, 0.827, 0.165, 1)', 'COL_TIE'),
    # settle: result_color
    (5542, 'Color(0.16, 0.65, 0.42, 1)  # #28A66A', 'COL_WIN'),
    (5545, 'Color(0.85, 0.70, 0.30, 1)  # #D9B34D', 'COL_TIE'),
    (5548, 'Color(0.80, 0.27, 0.27, 1)  # #CC4545', 'COL_LOSE'),
    # settle: amt_color
    (5564, 'Color(0.16, 0.65, 0.42, 1)', 'COL_WIN'),
    (5567, 'Color(0.85, 0.70, 0.30, 1)', 'COL_TIE'),
    (5570, 'Color(0.80, 0.27, 0.27, 1)', 'COL_LOSE'),
]


def main():
    with open(FILEPATH, 'r', encoding='utf-8') as f:
        original_lines = f.readlines()

    # Create working copy
    lines = list(original_lines)

    # ── Step 1: Insert new constants after line 22 (index 22, 0-based) ──
    # Line 22 is index 21. Insert after it (at index 22).
    insert_pos = 22  # 0-based index of the blank line after COL_BORDER
    const_lines = NEW_CONSTANTS.splitlines(keepends=True)
    # Ensure trailing newline on last line
    if const_lines and not const_lines[-1].endswith('\n'):
        const_lines[-1] += '\n'
    for i, cl in enumerate(const_lines):
        lines.insert(insert_pos + i, cl)

    # After insertion, minigame line numbers shift by len(const_lines)
    shift = len(const_lines)

    # ── Step 2: Apply replacements (adjust line numbers for shift) ──
    # Group replacements by adjusted line number
    from collections import defaultdict
    line_replacements = defaultdict(list)
    for line_num, old_frag, new_frag in REPLACEMENTS:
        adjusted = line_num - 1 + shift  # convert to 0-based + shift
        line_replacements[adjusted].append((old_frag, new_frag))

    errors = []
    for adjusted_idx, replacements in sorted(line_replacements.items()):
        for old_frag, new_frag in replacements:
            if adjusted_idx >= len(lines):
                errors.append(f"ERROR: line {adjusted_idx + 1 - shift} (adjusted {adjusted_idx + 1}) out of range")
                continue
            line = lines[adjusted_idx]
            if old_frag not in line:
                errors.append(f"WARNING: line {adjusted_idx + 1 - shift}: '{old_frag}' not found in: {line.rstrip()}")
                continue
            lines[adjusted_idx] = line.replace(old_frag, new_frag, 1)

    # ── Step 3: Write modified file ──
    with open(FILEPATH, 'w', encoding='utf-8') as f:
        f.writelines(lines)

    # ── Step 4: Generate unified diff ──
    diff = difflib.unified_diff(
        original_lines, lines,
        fromfile='scripts/MainGame.gd (original)',
        tofile='scripts/MainGame.gd (patched)',
        lineterm='\n'
    )
    diff_text = ''.join(diff)

    if diff_text:
        print(diff_text)
    else:
        print("No differences found.")

    if errors:
        print("\n=== ERRORS ===")
        for e in errors:
            print(e)

    # Summary
    total_replacements = len(REPLACEMENTS)
    print(f"\n=== SUMMARY ===")
    print(f"Constants inserted: {len(const_lines)} lines after line 22")
    print(f"Replacements attempted: {total_replacements}")
    print(f"Errors: {len(errors)}")
    print(f"Original lines: {len(original_lines)}, New lines: {len(lines)}")


if __name__ == '__main__':
    main()
