"""
tools/refine_menu_portraits.py
Standalone entry point for character menu portrait generation.
Delegates to build_perfect_ui_sprites for canonical logic.
"""

from build_perfect_ui_sprites import clean_and_refine_hal_menu, clean_and_refine_tainted_menu

if __name__ == "__main__":
    h = clean_and_refine_hal_menu()
    t = clean_and_refine_tainted_menu()
    print(f"Hal menu portrait: size={h.size}, bbox={h.getbbox()}")
    print(f"Tainted menu portrait: size={t.size}, bbox={t.getbbox()}")
