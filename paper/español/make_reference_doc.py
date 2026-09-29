"""Build the restrained Word style reference used by the Spanish article."""

from pathlib import Path

from docx import Document
from docx.enum.style import WD_STYLE_TYPE
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor


HERE = Path(__file__).resolve().parent
doc = Document()
section = doc.sections[0]
section.page_width = Cm(21.59)
section.page_height = Cm(27.94)
section.top_margin = Cm(2.54)
section.bottom_margin = Cm(2.54)
section.left_margin = Cm(2.54)
section.right_margin = Cm(2.54)
section.header_distance = Cm(1.25)
section.footer_distance = Cm(1.25)


def set_style(name, size, *, bold=False, italic=False, before=0, after=0,
              keep_next=False, line=1.22):
    style = doc.styles[name] if name in doc.styles else doc.styles.add_style(
        name, WD_STYLE_TYPE.PARAGRAPH
    )
    style.font.name = "Cambria"
    style.font.size = Pt(size)
    style.font.bold = bold
    style.font.italic = italic
    style.font.color.rgb = RGBColor(0, 0, 0)
    style.paragraph_format.space_before = Pt(before)
    style.paragraph_format.space_after = Pt(after)
    style.paragraph_format.line_spacing = line
    style.paragraph_format.keep_with_next = keep_next
    return style


normal = set_style("Normal", 11, after=6, line=1.73)
normal.paragraph_format.widow_control = True
body = set_style("Body Text", 11, after=6, line=1.73)
body.paragraph_format.widow_control = True
title = set_style("Title", 16, bold=True, after=10, line=1.1)
title.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER
subtitle = set_style("Subtitle", 11, after=5)
subtitle.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER
for level, size, before, after in ((1, 12, 14, 7), (2, 11, 10, 5), (3, 11, 8, 4)):
    set_style(f"Heading {level}", size, bold=True, before=before, after=after,
              keep_next=True, line=1.15)
caption = set_style("Caption", 10, after=5, keep_next=True, line=1.15)
caption.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.LEFT
bibliography = set_style("Bibliography", 10.5, after=4, line=1.15)
bibliography.paragraph_format.left_indent = Cm(1.27)
bibliography.paragraph_format.first_line_indent = Cm(-1.27)
set_style("Footnote Text", 9.5, line=1.1)

footer = section.footer.paragraphs[0]
footer.alignment = WD_ALIGN_PARAGRAPH.RIGHT
footer.style = doc.styles["Normal"]
field = OxmlElement("w:fldSimple")
field.set(qn("w:instr"), "PAGE")
footer._p.append(field)

doc.save(HERE / "reference-apa.docx")
