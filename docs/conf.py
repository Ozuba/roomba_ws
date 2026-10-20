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


# Godot scripts are indented with tabs, but reST expands tabs while parsing, so code copied
# from the docs would mix spaces into tab-indented files. Turn each leading 4-space group of
# the GDScript blocks back into a tab (the sources indent code with 4 spaces per level).
def _gdscript_tabs(app, doctree):
    import re
    from docutils import nodes

    for block in doctree.findall(nodes.literal_block):
        if block.get("language", highlight_language) != "gdscript":
            continue
        code = re.sub(
            r"^(?:    )+",
            lambda m: "\t" * (len(m.group()) // 4),
            block.astext(),
            flags=re.MULTILINE,
        )
        block.rawsource = code
        block[:] = [nodes.Text(code)]


def setup(app):
    app.connect("doctree-read", _gdscript_tabs)
