#!/usr/bin/env python3
"""Audita los insumos versionados y dos reconstrucciones aisladas del paper.

Uso: python3 output/review/paper_2026_09_auditoria_datos.py \
  --baseline /ruta/temporal/baseline --fresh /ruta/temporal/fresh

No modifica los datos de investigación; solo escribe productos paper_2026_09_*
en output/review.
"""

from __future__ import annotations

import argparse
import collections
import csv
import hashlib
import json
import shutil
from datetime import date
from decimal import Decimal
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT / "output" / "review"
RAW = ROOT / "data" / "raw" / "market"
PROCESSED = ROOT / "data" / "processed"
SERIES = ("trm", "colcap", "tes_1y", "tes_5y", "tes_10y", "energy_spot_price")


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def records(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def by_key(rows: list[dict[str, str]], *columns: str) -> dict[tuple[str, ...], dict[str, str]]:
    result = {}
    for row in rows:
        result[tuple(row[column] for column in columns)] = row
    return result


def write_csv(path: Path, rows: list[dict], fields: list[str]) -> None:
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def raw_profile() -> dict:
    output = {}
    for series in SERIES:
        path = RAW / f"{series}_raw.csv"
        rows = records(path)
        dates = [row["date"] for row in rows]
        output[series] = {
            "path": str(path.relative_to(ROOT)),
            "sha256": digest(path),
            "rows": len(rows),
            "nonmissing_values": sum(row[series] != "" for row in rows),
            "duplicate_dates": len(dates) - len(set(dates)),
            "first_date": min(dates),
            "last_date": max(dates),
        }
    return output


def market_profile(rows: list[dict[str, str]]) -> dict:
    dates = [row["date"] for row in rows]
    series = {}
    violations = collections.Counter()
    for name in SERIES + ("tes_slope_10y_1y",):
        has_value = lambda r: r[name] != ""
        observed = lambda r: r[f"{name}_observed"] == "TRUE"
        carried = lambda r: r[f"{name}_carried_forward"] == "TRUE"
        series[name] = {
            "nonmissing": sum(has_value(row) for row in rows),
            "observed": sum(observed(row) for row in rows),
            "carried_forward": sum(carried(row) for row in rows),
            "weekday_missing": sum(not has_value(row) and date.fromisoformat(row["date"]).weekday() < 5 for row in rows),
            "weekend_missing": sum(not has_value(row) and date.fromisoformat(row["date"]).weekday() >= 5 for row in rows),
        }
        for row in rows:
            if observed(row) and carried(row):
                violations["observed_and_carried"] += 1
            if carried(row) and date.fromisoformat(row["date"]).weekday() < 5:
                violations["weekday_carried"] += 1
            if (observed(row) or carried(row)) and not has_value(row):
                violations["flag_without_value"] += 1
    return {
        "rows": len(rows),
        "first_date": min(dates),
        "last_date": max(dates),
        "duplicate_dates": len(dates) - len(set(dates)),
        "weekdays": sum(date.fromisoformat(d).weekday() < 5 for d in dates),
        "weekends": sum(date.fromisoformat(d).weekday() >= 5 for d in dates),
        "series": series,
        "flag_violations": dict(violations),
    }


def tweet_profile(rows: list[dict[str, str]]) -> dict:
    groups = collections.defaultdict(list)
    ids = collections.Counter()
    for row in rows:
        groups[row["corpus"]].append(row)
        ids[(row["corpus"], row["id"])] += 1
    out = {"rows": len(rows), "duplicate_corpus_ids": sum(n - 1 for n in ids.values() if n > 1), "corpora": {}}
    for corpus, subset in sorted(groups.items()):
        dates = [row["date"] for row in subset]
        daily = collections.Counter(dates)
        hours = collections.Counter(row["timestamp_bogota"][11:13] for row in subset)
        span = (date.fromisoformat(max(dates)) - date.fromisoformat(min(dates))).days + 1
        out["corpora"][corpus] = {
            "rows": len(subset),
            "first_date": min(dates),
            "last_date": max(dates),
            "observed_days": len(daily),
            "calendar_span_days": span,
            "days_without_tweets": span - len(daily),
            "days_with_exactly_10_tweets": sum(n == 10 for n in daily.values()),
            "empty_text_clean": sum(row["text_clean"] == "" for row in subset),
            "non_spanish_lang": sum(row["lang"] != "es" for row in subset),
            "bogota_hour_18_rows": hours["18"],
            "utc_date_differs_from_bogota": sum(row["timestamp_utc"][:10] != row["timestamp_bogota"][:10] for row in subset),
            "date_differs_from_timestamp_bogota": sum(row["date"] != row["timestamp_bogota"][:10] for row in subset),
            "date_bogota_alias_errors": sum(row["date_bogota"] != row["date"] for row in subset),
            "source_files": len({row["source_file"] for row in subset}),
            "author_ids": len({row["author_id"] for row in subset}),
        }
    return out


def verify_raw_market_master(rows: list[dict[str, str]]) -> dict:
    master = {row["date"]: row for row in rows}
    result = {}
    for series in SERIES:
        raw = records(RAW / f"{series}_raw.csv")
        raw_dates = {row["date"] for row in raw}
        mismatches = 0
        for row in raw:
            date_key = row["date"]
            if date_key not in master or Decimal(row[series]) != Decimal(master[date_key][series]):
                mismatches += 1
        observed_dates = {row["date"] for row in rows if row[f"{series}_observed"] == "TRUE"}
        result[series] = {
            "value_mismatches": mismatches,
            "raw_dates_without_observed_flag": len(raw_dates - observed_dates),
            "observed_dates_without_raw": len(observed_dates - raw_dates),
        }
    return result


def compare_rebuild(baseline: Path, original_tweets: list[dict[str, str]]) -> dict:
    old_path = PROCESSED / "tweets_master.csv"
    new_path = baseline / "data" / "processed" / "tweets_master.csv"
    original = by_key(original_tweets, "corpus", "id")
    rebuilt = by_key(records(new_path), "corpus", "id")
    changes = collections.Counter()
    newline_only = collections.Counter()
    for key in original.keys() & rebuilt.keys():
        for column in original[key]:
            a, b = original[key][column], rebuilt[key][column]
            if a != b:
                changes[column] += 1
                if a.replace("\r\n", "\n").replace("\r", "\n") == b.replace("\r\n", "\n").replace("\r", "\n"):
                    newline_only[column] += 1
    old_market = PROCESSED / "market_master.csv"
    new_market = baseline / "data" / "processed" / "market_master.csv"
    return {
        "tweets_sha256_original": digest(old_path),
        "tweets_sha256_rebuilt": digest(new_path),
        "tweets_byte_equal": old_path.read_bytes() == new_path.read_bytes(),
        "tweet_keys_missing_from_rebuild": len(original.keys() - rebuilt.keys()),
        "tweet_keys_new_in_rebuild": len(rebuilt.keys() - original.keys()),
        "tweet_changed_fields": dict(changes),
        "tweet_newline_only_changes": dict(newline_only),
        "market_sha256_original": digest(old_market),
        "market_sha256_rebuilt": digest(new_market),
        "market_byte_equal": old_market.read_bytes() == new_market.read_bytes(),
    }


def compare_fresh(fresh: Path) -> dict:
    changes = []
    out = {}
    for series in SERIES:
        original_path = RAW / f"{series}_raw.csv"
        fresh_path = fresh / "data" / "raw" / "market" / f"{series}_raw.csv"
        original = {row["date"]: row[series] for row in records(original_path)}
        downloaded = {row["date"]: row[series] for row in records(fresh_path)}
        series_changes = []
        for d in sorted(original.keys() & downloaded.keys()):
            old, new = Decimal(original[d]), Decimal(downloaded[d])
            if old != new:
                difference = new - old
                item = {
                    "series": series,
                    "date": d,
                    "versioned_value": str(old),
                    "downloaded_value": str(new),
                    "difference": str(difference),
                    "relative_difference": str(difference / old) if old else "",
                }
                series_changes.append(item)
                changes.append(item)
        out[series] = {
            "sha256_versioned": digest(original_path),
            "sha256_downloaded": digest(fresh_path),
            "byte_equal": original_path.read_bytes() == fresh_path.read_bytes(),
            "versioned_rows": len(original),
            "downloaded_rows": len(downloaded),
            "missing_dates": len(original.keys() - downloaded.keys()),
            "new_dates": len(downloaded.keys() - original.keys()),
            "value_changes": len(series_changes),
            "changed_months": dict(sorted(collections.Counter(item["date"][:7] for item in series_changes).items())),
            "max_abs_difference": str(max((abs(Decimal(item["difference"])) for item in series_changes), default=Decimal(0))),
            "max_abs_relative_difference": str(max((abs(Decimal(item["relative_difference"])) for item in series_changes), default=Decimal(0))),
        }
    write_csv(
        REVIEW / "paper_2026_09_mercado_revisiones.csv",
        changes,
        ["series", "date", "versioned_value", "downloaded_value", "difference", "relative_difference"],
    )
    for source, target in (
        ("ingesta_mercado_fuentes.csv", "paper_2026_09_ingesta_fuentes.csv"),
        ("ingesta_mercado_cobertura.csv", "paper_2026_09_ingesta_cobertura.csv"),
    ):
        shutil.copy2(fresh / "output" / "tables" / "español" / source, REVIEW / target)
    return out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--fresh", type=Path)
    args = parser.parse_args()
    market_path = PROCESSED / "market_master.csv"
    tweets_path = PROCESSED / "tweets_master.csv"
    market_rows = records(market_path)
    tweet_rows = records(tweets_path)
    report = {
        "study_window": ["2022-08-01", "2026-05-31"],
        "files_sha256": {
            "data/processed/tweets_master.csv": digest(tweets_path),
            "data/processed/market_master.csv": digest(market_path),
        },
        "raw_market": raw_profile(),
        "market_master": market_profile(market_rows),
        "tweets_master": tweet_profile(tweet_rows),
        "raw_market_reconciliation": verify_raw_market_master(market_rows),
    }
    if args.baseline:
        report["isolated_rebuild"] = compare_rebuild(args.baseline, tweet_rows)
    if args.fresh:
        report["official_redownload"] = compare_fresh(args.fresh)
    target = REVIEW / "paper_2026_09_auditoria_datos.json"
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(target)


if __name__ == "__main__":
    main()
