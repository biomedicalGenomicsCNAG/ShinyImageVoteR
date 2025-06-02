import unittest
import os
import sqlite3
import sys

# Add server directory to sys.path to import setup_database
# This might be needed if running tests directly from the server directory or a parent directory
# Adjust the path as necessary based on your project structure and how tests are run.
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from setup_database import create_database, populate_data

class TestDatabaseSetup(unittest.TestCase):

    def setUp(self):
        """Set up for test methods."""
        self.test_db_path = "test_voting_app.db"
        self.test_data_file_path = "test_uro0003_paths.txt"
        # Ensure cleanup before each test
        if os.path.exists(self.test_db_path):
            os.remove(self.test_db_path)
        if os.path.exists(self.test_data_file_path):
            os.remove(self.test_data_file_path)

    def tearDown(self):
        """Tear down after test methods."""
        if os.path.exists(self.test_db_path):
            os.remove(self.test_db_path)
        if os.path.exists(self.test_data_file_path):
            os.remove(self.test_data_file_path)

    def create_dummy_data_file(self, content_lines):
        """Helper to create the dummy data file."""
        with open(self.test_data_file_path, 'w') as f:
            for line in content_lines:
                f.write(line + '\n')

    def test_create_database(self):
        """Test database creation and schema."""
        create_database(self.test_db_path)
        self.assertTrue(os.path.exists(self.test_db_path))

        conn = sqlite3.connect(self.test_db_path)
        cursor = conn.cursor()

        # Check if table exists
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='screenshots';")
        self.assertIsNotNone(cursor.fetchone(), "screenshots table should exist.")

        # Check table schema
        cursor.execute("PRAGMA table_info(screenshots);")
        columns_info = cursor.fetchall()
        expected_columns = {
            # Corrected expected schema based on typical PRAGMA table_info output
            # (cid, name, type, notnull, dflt_value, pk)
            "id": (0, "id", "INTEGER", 0, None, 1), # notnull can be 0 if PK implies it for INTEGER
            "coordinates": (1, "coordinates", "TEXT", 1, None, 0),
            "ref": (2, "ref", "TEXT", 1, None, 0),
            "alt": (3, "alt", "TEXT", 1, None, 0),
            "type_of_variant": (4, "type_of_variant", "TEXT", 1, None, 0),
            "path_to_screenshot": (5, "path_to_screenshot", "TEXT", 1, None, 0), # Uniqueness checked separately
            "votes": (6, "votes", "INTEGER", 1, "0", 0)
        }

        self.assertEqual(len(columns_info), len(expected_columns), "Number of columns mismatch.")

        for col_info in columns_info:
            col_name = col_info[1]
            self.assertIn(col_name, expected_columns, f"Unexpected column: {col_name}")
            expected_info = expected_columns[col_name]

            self.assertEqual(col_info[0], expected_info[0], f"CID mismatch for {col_name}") # cid
            self.assertEqual(col_info[2].upper(), expected_info[2].upper(), f"Type mismatch for {col_name}") # type
            self.assertEqual(col_info[3], expected_info[3], f"NOT NULL mismatch for {col_name}") # notnull
            # Default value can be tricky, sqlite might return it differently. '0' vs 0
            if expected_info[4] is not None:
                 self.assertEqual(str(col_info[4]), str(expected_info[4]), f"Default value mismatch for {col_name}")
            self.assertEqual(col_info[5], expected_info[5], f"Primary Key mismatch for {col_name}") # pk

        # Check UNIQUE constraint on path_to_screenshot by querying index list
        cursor.execute("PRAGMA index_list(screenshots);")
        indexes = cursor.fetchall()
        unique_index_exists_for_path = any('path_to_screenshot' in idx[1] and idx[2] == 1 for idx in indexes if idx[3] == 'u') # idx[3] == 'u' for UNIQUE
        # Alternatively, check the SQL schema directly
        cursor.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='screenshots';")
        schema_sql = cursor.fetchone()[0]
        self.assertIn("UNIQUE (path_to_screenshot)", schema_sql.upper().replace("\n", " "))

        conn.close()

    def test_populate_data_empty_file(self):
        """Test populating data with an empty file."""
        self.create_dummy_data_file([])
        create_database(self.test_db_path) # Create schema first
        populate_data(self.test_db_path, self.test_data_file_path)

        conn = sqlite3.connect(self.test_db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM screenshots;")
        self.assertEqual(cursor.fetchone()[0], 0, "Table should be empty for empty data file.")
        conn.close()

    def test_populate_data_valid_entries(self):
        """Test populating data with valid entries."""
        valid_data = [
            "chr1:100\tA\tT\tSNV\tpath/to/img1.png",
            "chrX:200\tG\tC\tINDEL\tpath/to/img2.png"
        ]
        self.create_dummy_data_file(valid_data)
        create_database(self.test_db_path)
        populate_data(self.test_db_path, self.test_data_file_path)

        conn = sqlite3.connect(self.test_db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT coordinates, ref, alt, type_of_variant, path_to_screenshot, votes FROM screenshots ORDER BY id;")
        rows = cursor.fetchall()
        self.assertEqual(len(rows), 2)

        expected_rows = [
            ("chr1:100", "A", "T", "SNV", "path/to/img1.png", 0),
            ("chrX:200", "G", "C", "INDEL", "path/to/img2.png", 0)
        ]
        self.assertEqual(rows, expected_rows)
        conn.close()

    def test_populate_data_skips_malformed_lines(self):
        """Test that malformed lines in the data file are skipped."""
        mixed_data = [
            "chr1:100\tA\tT\tSNV\tpath/to/img1.png",  # Valid
            "chrY:500\tG\t\tSNV\tpath/to/img3.png", # Valid, alt can be empty string if not strictly disallowed by db, but here it is NOT NULL
            "malformed_line_too_few_fields",
            "chr2:200\tC\tG\tINDEL\tpath/to/img2.png\textra_field", # Too many fields
            "chr3:300\tN\tN\tSNV\tpath/to/img4.png" # Valid
        ]
        self.create_dummy_data_file(mixed_data)
        create_database(self.test_db_path)

        # As setup_database.py prints warnings, we can optionally capture stdout/stderr
        # For now, just check DB state
        populate_data(self.test_db_path, self.test_data_file_path)

        conn = sqlite3.connect(self.test_db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT path_to_screenshot FROM screenshots ORDER BY id;")
        rows = cursor.fetchall()

        # Expecting 3 valid rows: img1, img3 (assuming empty alt is allowed by split but might fail on NOT NULL if empty), img4.
        # The current setup_database.py has NOT NULL on alt. So "chrY:500\tG\t\tSNV\tpath/to/img3.png" will fail on insert.
        # The script currently prints an error for failed inserts but continues.
        # So only img1 and img4 should be inserted.

        inserted_paths = [row[0] for row in rows]
        self.assertIn("path/to/img1.png", inserted_paths)
        self.assertIn("path/to/img4.png", inserted_paths)
        self.assertNotIn("path/to/img3.png", inserted_paths) # This would fail due to NOT NULL on 'alt' if it becomes empty string
        self.assertEqual(len(inserted_paths), 2, "Should only insert valid lines that don't violate constraints.")
        conn.close()

    def test_populate_data_unique_constraint_violation(self):
        """Test that unique constraint on path_to_screenshot is handled."""
        duplicate_data = [
            "chr1:100\tA\tT\tSNV\tpath/to/img1.png",
            "chr1:101\tA\tT\tSNV\tpath/to/img1.png" # Duplicate path
        ]
        self.create_dummy_data_file(duplicate_data)
        create_database(self.test_db_path)
        # populate_data should print an error for the duplicate but continue
        populate_data(self.test_db_path, self.test_data_file_path)

        conn = sqlite3.connect(self.test_db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM screenshots;")
        # Only the first entry should be inserted
        self.assertEqual(cursor.fetchone()[0], 1, "Should only insert one record due to UNIQUE constraint.")
        conn.close()

    def test_create_database_idempotent(self):
        """Test that calling create_database multiple times is idempotent."""
        create_database(self.test_db_path) # First call
        # Get schema or row count or some state
        conn = sqlite3.connect(self.test_db_path)
        cursor = conn.cursor()
        cursor.execute("PRAGMA table_info(screenshots);")
        schema_before = cursor.fetchall()
        conn.close()

        create_database(self.test_db_path) # Second call
        self.assertTrue(os.path.exists(self.test_db_path)) # Still exists

        conn_after = sqlite3.connect(self.test_db_path)
        cursor_after = conn_after.cursor()
        cursor_after.execute("PRAGMA table_info(screenshots);")
        schema_after = cursor_after.fetchall()
        conn_after.close()

        self.assertEqual(schema_before, schema_after, "Schema should be unchanged after second call.")
        # Additionally, you could try inserting data and ensure it doesn't get wiped out if that's the desired behavior of "IF NOT EXISTS"

if __name__ == '__main__':
    unittest.main()
