"""Extract Olist CSVs + BRL/USD FX rates and load them into DuckDB (raw schema)."""
import shutil
import subprocess
from datetime import date, timedelta
from pathlib import Path

import duckdb
import requests

ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = ROOT / "data" / "raw"
DB_PATH = ROOT / "warehouse" / "olist.duckdb"

KAGGLE_DATASET = "olistbr/brazilian-ecommerce"
FX_URL = "https://api.frankfurter.dev/v1"
FX_START, FX_END = date(2016, 9, 1), date(2018, 10, 31)

CSV_TABLES = {
    "olist_customers_dataset.csv": "olist_customers",
    "olist_geolocation_dataset.csv": "olist_geolocation",
    "olist_order_items_dataset.csv": "olist_order_items",
    "olist_order_payments_dataset.csv": "olist_order_payments",
    "olist_order_reviews_dataset.csv": "olist_order_reviews",
    "olist_orders_dataset.csv": "olist_orders",
    "olist_products_dataset.csv": "olist_products",
    "olist_sellers_dataset.csv": "olist_sellers",
    "product_category_name_translation.csv": "product_category_translation",
}


def download_olist() -> None:
    """Download the dataset from Kaggle unless the CSVs are already there."""
    if any(RAW_DIR.glob("olist_*.csv")):
        print("Olist CSVs already present, skipping download.")
        return
    kaggle = shutil.which("kaggle")
    if kaggle is None:
        raise RuntimeError("Kaggle CLI not found. Is your venv activated?")
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [kaggle, "datasets", "download", "-d", KAGGLE_DATASET,
         "-p", str(RAW_DIR), "--unzip"],
        check=True,
    )


def load_csvs(con: duckdb.DuckDBPyConnection) -> None:
    """Load every CSV as-is (all columns as text); dbt will clean and cast later."""
    con.execute("CREATE SCHEMA IF NOT EXISTS raw")
    for filename, table in CSV_TABLES.items():
        path = (RAW_DIR / filename).as_posix()
        con.execute(f"""
            CREATE OR REPLACE TABLE raw.{table} AS
            SELECT *, current_timestamp AS _loaded_at
            FROM read_csv('{path}', header = true, all_varchar = true)
        """)
        print(f"Loaded raw.{table}")


def fetch_fx_rates() -> list[tuple]:
    """Pull daily BRL->USD rates from the Frankfurter API in 90-day chunks."""
    rows, start = [], FX_START
    while start <= FX_END:
        end = min(start + timedelta(days=89), FX_END)
        resp = requests.get(
            f"{FX_URL}/{start}..{end}",
            params={"base": "BRL", "symbols": "USD"},
            timeout=30,
        )
        resp.raise_for_status()
        for rate_date, rates in resp.json()["rates"].items():
            rows.append((rate_date, "BRL", "USD", rates["USD"]))
        start = end + timedelta(days=1)
    return rows


def load_fx(con: duckdb.DuckDBPyConnection) -> None:
    rows = fetch_fx_rates()
    con.execute("""
        CREATE OR REPLACE TABLE raw.fx_rates (
            rate_date DATE, base_currency VARCHAR, quote_currency VARCHAR,
            rate DOUBLE, _loaded_at TIMESTAMP
        )
    """)
    con.executemany(
        "INSERT INTO raw.fx_rates VALUES (?, ?, ?, ?, current_timestamp)", rows
    )
    print(f"Loaded raw.fx_rates ({len(rows)} rows)")


def main() -> None:
    download_olist()
    DB_PATH.parent.mkdir(exist_ok=True)
    con = duckdb.connect(str(DB_PATH))
    try:
        load_csvs(con)
        load_fx(con)
        print("\nRow counts:")
        tables = con.execute(
            "SELECT table_name FROM information_schema.tables "
            "WHERE table_schema = 'raw' ORDER BY 1"
        ).fetchall()
        for (t,) in tables:
            n = con.execute(f"SELECT count(*) FROM raw.{t}").fetchone()[0]
            print(f"  raw.{t}: {n:,}")
    finally:
        con.close()


if __name__ == "__main__":
    main()