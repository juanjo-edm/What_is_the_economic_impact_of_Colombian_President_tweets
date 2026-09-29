"""Make Quarto's Word floats usable in Word and LibreOffice.

Quarto wraps each numbered table or figure in a single-cell table.  Its nested
tables render as a vertical list of cells in LibreOffice, with stray headings
and large empty areas.  Rebuild the six tables as native Word tables, unwrap
the float containers, and retain captions, figures and cross-reference XML.
"""

from pathlib import Path
import re
import sys

from docx import Document
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt


WIDTHS = [
    [0.22, 0.40, 0.38],
    [0.25, 0.16, 0.18, 0.41],
    [0.39, 0.15, 0.14, 0.32],
    [0.32, 0.25, 0.43],
    [0.25, 0.16, 0.16, 0.17, 0.26],
    [0.25, 0.16, 0.16, 0.17, 0.26],
]


def element(name, **attrs):
    item = OxmlElement(name)
    for key, value in attrs.items():
        item.set(qn(key), str(value))
    return item


def set_border(parent, edge, size=6):
    border = element(f"w:{edge}", **{"w:val": "single", "w:sz": size, "w:color": "000000"})
    parent.append(border)


def repair_table(table, fractions, content_width):
    assert len(table.columns) == len(fractions)
    # A fresh table is necessary here: the Pandoc nested table XML renders its
    # cells vertically even when widths and styles are repaired in place.
    table.style = "Normal Table"
    table.autofit = False
    widths = [round(content_width * f) for f in fractions]
    widths[-1] = content_width - sum(widths[:-1])
    tbl_pr = table._tbl.tblPr
    tbl_w = tbl_pr.find(qn("w:tblW"))
    tbl_w.set(qn("w:type"), "dxa")
    tbl_w.set(qn("w:w"), str(content_width))
    for column, width in zip(table._tbl.tblGrid.gridCol_lst, widths):
        column.set(qn("w:w"), str(width))
    borders = tbl_pr.find(qn("w:tblBorders"))
    if borders is None:
        borders = element("w:tblBorders")
        tbl_pr.append(borders)
    set_border(borders, "top")
    set_border(borders, "bottom")
    for row_i, row in enumerate(table.rows):
        if row_i == 0:
            tr_pr = row._tr.get_or_add_trPr()
            tr_pr.append(element("w:tblHeader", **{"w:val": "true"}))
        for cell, width in zip(row.cells, widths):
            tc_w = cell._tc.get_or_add_tcPr().find(qn("w:tcW"))
            if tc_w is None:
                tc_w = element("w:tcW")
                cell._tc.get_or_add_tcPr().append(tc_w)
            tc_w.set(qn("w:type"), "dxa")
            tc_w.set(qn("w:w"), str(width))
            if row_i == 0:
                tc_borders = cell._tc.get_or_add_tcPr().find(qn("w:tcBorders"))
                if tc_borders is None:
                    tc_borders = element("w:tcBorders")
                    cell._tc.get_or_add_tcPr().append(tc_borders)
                set_border(tc_borders, "bottom")
            for paragraph in cell.paragraphs:
                paragraph.paragraph_format.space_before = Pt(1)
                paragraph.paragraph_format.space_after = Pt(2)
                paragraph.paragraph_format.line_spacing = 1.0
                paragraph.paragraph_format.keep_with_next = False
                for run in paragraph.runs:
                    run.font.name = "Cambria"
                    run.font.size = Pt(8.5)
                    if row_i == 0:
                        run.bold = True


def main(path):
    doc = Document(path)
    outer = list(doc.tables)
    assert len(outer) == 11, f"Expected 6 tables and 5 figures; found {len(outer)} floats"
    count = 0
    for float_table in outer:
        assert len(float_table.rows) == len(float_table.columns) == 1
        cell = float_table.cell(0, 0)
        replacement = None
        if cell.tables:
            assert len(cell.tables) == 1
            old = cell.tables[0]
            replacement = doc.add_table(rows=len(old.rows), cols=len(old.columns))
            for row_i, row in enumerate(old.rows):
                for col_i, old_cell in enumerate(row.cells):
                    value = old_cell.text.strip()
                    if count == 0 and row_i == 4 and col_i == 1:
                        value = "z(polaridad/n) × z[log(1+n)] dentro de cada universo declarado"
                    replacement.cell(row_i, col_i).text = value
            repair_table(replacement, WIDTHS[count], 9360)
            count += 1
        body = float_table._tbl.getparent()
        position = body.index(float_table._tbl)
        for child in list(cell._tc):
            if child.tag == qn("w:tcPr"):
                continue
            if child.tag == qn("w:tbl"):
                assert replacement is not None
                body.insert(position, replacement._tbl)
                position += 1
                continue
            if child.tag == qn("w:p") and not child.xpath('.//w:t|.//w:drawing|.//m:oMath'):
                continue
            cell._tc.remove(child)
            body.insert(position, child)
            position += 1
        body.remove(float_table._tbl)
    assert count == 6
    # LibreOffice's PDF conversion appends a visible "X" after paragraphs that
    # contain Word hyperlinks.  Keep their displayed text, including citations,
    # while removing the wrappers from the editorial Word deliverable.
    for hyperlink in list(doc.element.body.xpath('.//w:hyperlink')):
        parent = hyperlink.getparent()
        position = parent.index(hyperlink)
        for child in list(hyperlink):
            hyperlink.remove(child)
            parent.insert(position, child)
            position += 1
        parent.remove(hyperlink)
    for paragraph in doc.paragraphs:
        if re.match(r"^Tabla\s+\d+:", paragraph.text):
            paragraph.paragraph_format.keep_with_next = True
            paragraph.paragraph_format.keep_together = True
        if paragraph.text.strip() == "4. Resultados":
            paragraph.paragraph_format.page_break_before = True
    doc.save(path)
    print(f"Unwrapped {len(outer)} floats and sized {count} tables: {path}")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
