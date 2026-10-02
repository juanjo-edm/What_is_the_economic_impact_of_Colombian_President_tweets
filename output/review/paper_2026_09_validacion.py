"""Recheck the figures used in the Spanish article against regenerated outputs."""

import csv
import json
import math
import re
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path
from xml.etree import ElementTree as ET
from zoneinfo import ZoneInfo
from zipfile import ZipFile


ROOT = Path(__file__).resolve().parents[2]
TABLES = ROOT / "output/tables/español"
PAPER = ROOT / "paper/español/quarto-tandf.qmd"
WORD = ROOT / "paper/English/Paper_Mensajes_Presidenciales_Mercados_Colombia_ES.docx"


def rows(path):
    with open(path, newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def bh(values):
    ordered = sorted(enumerate(values), key=lambda pair: pair[1])
    result = [0.0] * len(values)
    current = 1.0
    for rank in range(len(values), 0, -1):
        index, value = ordered[rank - 1]
        current = min(current, value * len(values) / rank)
        result[index] = current
    return result


def check():
    report = {}
    tweets = rows(ROOT / "data/processed/tweets_master.csv")
    assert len(tweets) == 28307
    assert Counter(row["corpus"] for row in tweets) == {"opinion": 13648, "presidente": 14659}
    assert len({(row["corpus"], row["id"]) for row in tweets}) == len(tweets)
    for row in tweets:
        moment = datetime.fromisoformat(row["timestamp_utc"].replace("Z", "+00:00"))
        assert moment.astimezone(ZoneInfo("America/Bogota")).date().isoformat() == row["date_bogota"]
    report["tweets"] = {"rows": len(tweets), "corpora": dict(Counter(row["corpus"] for row in tweets)), "local_dates_valid": True}

    panel = rows(ROOT / "output/review/paper_2026_09_panel_comparacion.csv")
    assert len(panel) == 934
    dates = [row["fecha_respuesta_bursatil"] for row in panel]
    assert len(set(dates)) == len(dates) and dates == sorted(dates)
    repeated = sum(int(row["retornos_repetidos_panel_anterior"]) for row in panel)
    multidate = sum(int(row["fechas_textuales_panel_anterior"]) > 1 for row in panel)
    assert repeated == 463 and multidate == 209
    assert all(int(row["filas_panel_corregido"]) == 1 for row in panel)
    report["panel"] = {"sessions": len(panel), "old_repeated_returns": repeated, "multidate_sessions": multidate}

    audit = rows(TABLES / "00_auditoria_temporal_paneles.csv")
    main = next(row for row in audit if row["componente"] == "panel_bursatil_principal")
    assert (int(main["filas"]), int(main["observaciones_modelables"])) == (934, 882)

    granger = rows(TABLES / "granger_resultados_completos.csv")
    assert len(granger) == 208
    families = defaultdict(list)
    for row in granger:
        families[row["dataset"]].append(row)
    assert {key: len(value) for key, value in families.items()} == {"comunicación presidencial": 112, "panel por corpus": 96}
    for family in families.values():
        adjusted = bh([float(row["p_value"]) for row in family])
        for row, q in zip(family, adjusted):
            assert math.isclose(float(row["q_value"]), q, rel_tol=1e-10, abs_tol=1e-10)
    nominal = sum(float(row["p_value"]) < 0.05 for row in granger)
    adjusted = sum(float(row["q_value"]) < 0.05 for row in granger)
    assert (nominal, adjusted) == (12, 0)
    report["granger"] = {"tests": len(granger), "families": {key: len(value) for key, value in families.items()}, "nominal": nominal, "fdr": adjusted}

    dcc = rows(TABLES / "07_dcc_financiero_diagnostico.csv")
    assert len(dcc) == 1 and (int(dcc[0]["observaciones"]), int(dcc[0]["convergencia"])) == (882, 0)
    dcc_params = {row["parametro"]: row for row in rows(TABLES / "07_dcc_financiero_parametros.csv")}
    assert float(dcc_params["[Joint]dcca1"]["p_value"]) > 0.05
    report["dcc"] = {"observations": 882, "convergence_code": 0, "reaction_p": float(dcc_params["[Joint]dcca1"]["p_value"])}

    transition = rows(TABLES / "11_markov_matriz_transicion.csv")
    assert len(transition) == 2
    for row in transition:
        assert math.isclose(sum(float(value) for key, value in row.items() if key != "De"), 1.0, abs_tol=1e-12)
    regimes = rows(TABLES / "11_markov_regimenes.csv")
    assert "duracion_esperada_sesiones" in regimes[0]
    report["markov"] = {"row_sums_valid": True, "duration_unit": "sessions"}

    metrics = rows(TABLES / "ml_metricas_temas.csv")
    supports = defaultdict(int)
    for row in metrics:
        if row["clase"] != "macro_promedio":
            supports[row["modelo"]] += int(row["soporte"])
    assert set(supports.values()) == {2361}
    report["classifier"] = {"support_by_model": dict(supports)}

    events = rows(TABLES / "event_study_resumen.csv")
    assert {int(row["horizonte"]) for row in events} == {1, 3, 5, 7}
    assert all(0 <= int(row["eventos_con_dato"]) <= 10 for row in events)
    seven_day = {(row["evento"], row["serie"]): row for row in events if row["horizonte"] == "7"}
    assert round(100 * float(seven_day[("IPI extremo", "COLCAP")]["movimiento_medio"]), 2) == 0.76
    assert round(100 * float(seven_day[("IPI extremo", "Precio energía XM")]["movimiento_medio"]), 2) == 31.89
    assert round(100 * float(seven_day[("negatividad extrema", "Precio energía XM")]["movimiento_medio"]), 2) == 12.17
    report["events"] = {"rows": len(events), "horizons_calendar_days": [1, 3, 5, 7], "units": sorted({row["unidad"] for row in events})}

    themes = rows(TABLES / "temas_reforma_resumen.csv")
    by_corpus = defaultdict(int)
    for row in themes:
        by_corpus[row["corpus"]] += int(row["tweets"])
    assert dict(by_corpus) == {"opinion": 8349, "presidente": 10784}
    ipi = rows(TABLES / "ipi_resumen.csv")
    assert len(ipi) == 1 and int(ipi[0]["dias"]) == 1271
    assert round(float(ipi[0]["ipi_media"]), 3) == 0.005
    report["text_signals"] = {"classified_by_corpus": dict(by_corpus), "ipi_days": 1271}

    text = PAPER.read_text(encoding="utf-8")
    for literal in ["13.648", "14.659", "934", "882", "463", "208", "12"]:
        assert literal in text
    bib = (ROOT / "paper/español/bibliography.bib").read_text(encoding="utf-8")
    bib_keys = set(re.findall(r"(?m)^@\w+\s*\{\s*([^,]+),", bib))
    cited = set(re.findall(r"(?<![\w.])@([\w-]+)", text)) & bib_keys
    assert len(cited) == 26
    ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
    with ZipFile(WORD) as archive:
        xml = ET.fromstring(archive.read("word/document.xml"))
    bookmarks = {e.attrib[f"{{{ns['w']}}}name"][4:] for e in xml.findall(".//w:bookmarkStart", ns) if e.attrib.get(f"{{{ns['w']}}}name", "").startswith("ref-")}
    assert cited == bookmarks
    report["references"] = {"cited": len(cited), "printed": len(bookmarks), "exact_match": True}
    assert len(xml.findall("./w:body/w:tbl", ns)) == 6
    assert len(xml.findall(".//{http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing}docPr")) == 5
    for required in ["Juan José Echeverry De Mendoza", "Miguelangel Palma Rojas", "Luis Eduardo Sandoval Garrido", "Los autores declaran no tener conflictos de interés", "Esta investigación no recibió financiación"]:
        assert required in text
    report["manuscript"] = {"figures": 5, "tables": 6, "authors": 3, "declarations_checked": True}

    (ROOT / "output/review/paper_2026_09_validacion.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    check()
