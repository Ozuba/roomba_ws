# Sphinx configuration for the rclgd Roomba workshop.

project = "rclgd Roomba Workshop"
author = "Miguel Oroz Zubasti"
copyright = "2026, Miguel Oroz Zubasti"
release = "1.0"

extensions = [
    "sphinx.ext.autosectionlabel",
    "sphinxcontrib.mermaid",
    "sphinx_copybutton",
]

# Section labels are prefixed with their document, so headings like "Check it" can repeat
# across tutorial steps without clashing.
autosectionlabel_prefix_document = True

exclude_patterns = ["_build", "Thumbs.db", ".DS_Store"]

# Most code in the tutorial is GDScript (Pygments ships a lexer for it).
highlight_language = "gdscript"
# Pygments' GDScript lexer predates annotations (@export, @onready): it falls back to relaxed
# mode for those blocks, which still highlights them fine.
suppress_warnings = ["misc.highlighting_failure"]

html_theme = "sphinx_rtd_theme"
html_static_path = ["_static"]
html_css_files = ["custom.css"]
html_logo = "_static/images/logo.svg"
html_title = "rclgd Roomba Workshop"
html_theme_options = {
    "navigation_depth": 2,
    "collapse_navigation": False,
}

# Don't copy shell prompts when using the copy button
copybutton_prompt_text = r"\$ |>>> "
copybutton_prompt_is_regexp = True
