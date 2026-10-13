"""
tools/generate_all_redesigns.py
Proxy module exposing the canonical render functions from build_character_redesign.py
"""

from tools.build_character_redesign import (
    render_hal_head_front,
    render_hal_head_side,
    render_hal_head_back,
    render_hal_head_sad,
    render_tainted_head_front,
    render_tainted_head_side,
    render_tainted_head_back,
    render_hal_body_front,
    render_tainted_body_front,
    assemble_full,
    generate_all
)

if __name__ == "__main__":
    generate_all()
