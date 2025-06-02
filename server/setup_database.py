import sqlite3
import sys

def create_database(db_path):
    """Creates the database and the screenshots table."""
    print(f"INFO: Attempting to connect to database at '{db_path}'...")
    try:
        conn = sqlite3.connect(db_path)
        print("INFO: Database connected successfully.")
    except sqlite3.Error as e:
        print(f"ERROR: Failed to connect to database at '{db_path}': {e}")
        sys.exit(1)

    cursor = conn.cursor()
    print("INFO: Creating 'screenshots' table if it doesn't exist...")
    try:
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS screenshots (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                coordinates TEXT NOT NULL,
                ref TEXT NOT NULL,
                alt TEXT NOT NULL,
                type_of_variant TEXT NOT NULL,
                path_to_screenshot TEXT NOT NULL UNIQUE,
                votes INTEGER NOT NULL DEFAULT 0
            )
        ''')
        conn.commit()
        print("INFO: 'screenshots' table created or already exists.")
    except sqlite3.Error as e:
        print(f"ERROR: Failed to create 'screenshots' table: {e}")
        conn.close()
        sys.exit(1)

    conn.close()
    print("INFO: Database connection closed for create_database.")

def populate_data(db_path, data_file_path):
    """Populates the screenshots table from the data file."""
    print(f"INFO: Attempting to connect to database at '{db_path}' for data population...")
    try:
        conn = sqlite3.connect(db_path)
        print("INFO: Database connected successfully for data population.")
    except sqlite3.Error as e:
        print(f"ERROR: Failed to connect to database at '{db_path}' for data population: {e}")
        sys.exit(1)

    cursor = conn.cursor()
    print(f"INFO: Attempting to populate data from '{data_file_path}'...")
    try:
        with open(data_file_path, 'r') as f:
            for i, line in enumerate(f):
                parts = line.strip().split('\t')
                if len(parts) == 5:
                    coordinates, ref, alt, type_of_variant, path_to_screenshot = parts
                    try:
                        cursor.execute('''
                            INSERT INTO screenshots (coordinates, ref, alt, type_of_variant, path_to_screenshot, votes)
                            VALUES (?, ?, ?, ?, ?, ?)
                        ''', (coordinates, ref, alt, type_of_variant, path_to_screenshot, 0))
                    except sqlite3.Error as e:
                        print(f"ERROR: Failed to insert row {i+1} ('{line.strip()}') into 'screenshots' table: {e}")
                        # Decide if you want to skip this row or exit. For now, skipping.
                else:
                    print(f"WARNING: Skipping malformed line {i+1} in '{data_file_path}': {line.strip()}")
        conn.commit()
        print(f"INFO: Finished populating data from '{data_file_path}'.")
    except FileNotFoundError:
        print(f"ERROR: Data file '{data_file_path}' not found.")
        conn.close()
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: An unexpected error occurred during data population from '{data_file_path}': {e}")
        conn.close()
        sys.exit(1)
    finally:
        if conn:
            conn.close()
            print("INFO: Database connection closed for populate_data.")

if __name__ == "__main__":
    db_path = 'server/voting_app.db'
    # Intentionally using a potentially non-existent file for testing FileNotFoundError
    # data_file_path = 'server/uro0003_paths_potentially_missing.txt'
    data_file_path = 'server/uro0003_paths.txt'


    print("INFO: Starting database setup process...")
    create_database(db_path)
    populate_data(db_path, data_file_path)

    print(f"INFO: Database '{db_path}' setup process completed successfully.")
