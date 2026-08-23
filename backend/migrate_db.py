import pandas as pd
from sqlalchemy import create_engine, inspect, text
import uuid

def migrate_postgres_to_sqlite():
    PG_URL = "postgresql://postgres:PmAVykhkuGlobLuajglGCLAIAKQgCNyY@acela.proxy.rlwy.net:50723/railway"
    SQLITE_URL = "sqlite:///db.sqlite3"

    print("🟢 Connecting to databases...")
    
    try:
        pg_engine = create_engine(PG_URL)
        sqlite_engine = create_engine(SQLITE_URL)
        
        inspector = inspect(pg_engine)
        tables = inspector.get_table_names()
        
        excluded_tables = [
            'django_migrations', 
            'django_content_type', 
            'auth_permission', 
            'django_admin_log',
            'django_session'
        ]
        
        target_tables = [t for t in tables if t not in excluded_tables]

        print(f"📊 Found {len(target_tables)} tables to migrate. Starting copy...\n")

        for table in target_tables:
            print(f"⏳ Migrating table: {table}...")
            try:
                df = pd.read_sql_table(table, pg_engine)

                if df.empty:
                    print(f"  ⏩ Skipping {table}: Table is empty.")
                    continue

                for col in df.columns:
                    df[col] = df[col].apply(
                        lambda x: str(x) if isinstance(x, (dict, list, uuid.UUID)) else x
                    )

                # --- NEW FIX: Manually inject missing defaults for Pandas ---
                if table == 'api_landlordprofile':
                    if 'subscription_type' not in df.columns:
                        df['subscription_type'] = 'MONTHLY'
                    if 'is_active_subscriber' not in df.columns:
                        df['is_active_subscriber'] = False
                    if 'trial_start_date' not in df.columns:
                        df['trial_start_date'] = None
                    if 'next_billing_date' not in df.columns:
                        df['next_billing_date'] = None

                with sqlite_engine.begin() as conn:
                    conn.execute(text(f"DELETE FROM {table};"))
                    
                df.to_sql(table, sqlite_engine, if_exists='append', index=False)
                
                print(f"  ✅ Successfully copied {len(df)} rows.")
            except Exception as e:
                print(f"  ❌ ERROR migrating {table}: {e}")

        print("\n🎉 Migration complete! Your local SQLite database is fully synced with Live.")
        
    except Exception as e:
        print(f"🚨 Connection failed: {e}")

if __name__ == "__main__":
    migrate_postgres_to_sqlite()