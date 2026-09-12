# Market raw data

This folder stores the official raw market series downloaded before processing.

Expected files after running `Rscript scripts/data/ingest_market.R`:

- `trm_raw.csv`
- `colcap_raw.csv`
- `tes_1y_raw.csv`
- `tes_5y_raw.csv`
- `tes_10y_raw.csv`
- `energy_spot_price_raw.csv`

These files are the auditable raw inputs. The processing step
`Rscript scripts/data/twitter_process_raw_data.R` reads them, fills weekend gaps
for daily analytical continuity in financial market series, derives
`tes_slope_10y_1y`, and writes the processed market files under
`data/processed/`.

`energy_spot_price_raw.csv` comes from the XM SINERGOX daily API metric
`PPPrecBolsNaci` for entity `Sistema` and stores the national weighted spot
price in `COP/kWh`. It is processed without weekend carry-forward: if XM does
not report a day, the processed value remains missing.
