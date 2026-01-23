# Development Scripts

This directory contains scripts for testing and development purposes.

## test_database_update.R

Script to manually test the database update functionality.

### Usage

```bash
# Make sure the package is installed first
make install

# Run the test script
Rscript dev_scripts/test_database_update.R
```

### Manual Testing with Running App

1. Start the Shiny app:
   ```bash
   make run
   ```

2. While the app is running, modify the `to_be_voted_images_file` (default: `./app_env/images/to_be_voted_images.tsv`)

3. Add new entries to the file. For example:
   ```tsv
   coordinates	REF	ALT	path
   chr7:7000	A	G	./app_env/images/pngs/example_new.png
   ```

4. Wait approximately 5 seconds (the file watcher checks every 5 seconds)

5. You should see:
   - A notification in the app (for admin users): "Database updated: X new entries added"
   - A console message: "Added X new entries to annotations table"
   - The new entries will be available for voting

### Notes

- The file watcher only adds entries that don't already exist in the database
- Uniqueness is determined by the combination of coordinates, REF, and ALT
- If the file is modified but no new entries are found, no notification is shown
- Any errors during the update process are logged and shown as error notifications
