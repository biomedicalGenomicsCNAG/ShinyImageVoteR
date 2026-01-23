# Feature Flow Diagram

## Database Update Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         Shiny App Starts                        │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│          Initialize File Watcher (main_server.R)                │
│  • Store initial modification time of to_be_voted_images_file   │
│  • Start periodic check (every 5 seconds)                       │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
                    ┌────────────────┐
                    │  Every 5 sec   │
                    └────────┬───────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              Check File Modification Time                       │
│  • Get current mtime of to_be_voted_images_file                 │
│  • Compare with last known mtime                                │
└────────────────────────────┬────────────────────────────────────┘
                             │
                  ┌──────────┴──────────┐
                  │                     │
            No Change                 Changed
                  │                     │
                  ▼                     ▼
         ┌────────────────┐   ┌────────────────────────────────┐
         │ Update mtime   │   │ Call update_annotations_table()│
         │ Continue loop  │   │     (db_utils.R)               │
         └────────────────┘   └────────┬───────────────────────┘
                                       │
                                       ▼
                     ┌─────────────────────────────────────┐
                     │   Read to_be_voted_images_file      │
                     │   Get existing DB entries           │
                     │   Create unique keys:               │
                     │   key = coordinates|REF|ALT         │
                     └──────────┬──────────────────────────┘
                                │
                                ▼
                     ┌─────────────────────────────────────┐
                     │   Find New Entries                  │
                     │   new = file_keys - db_keys         │
                     └──────────┬──────────────────────────┘
                                │
                      ┌─────────┴─────────┐
                      │                   │
                 No New Entries      New Entries Found
                      │                   │
                      ▼                   ▼
            ┌──────────────────┐  ┌─────────────────────────┐
            │ Log: No new      │  │ Process paths           │
            │ entries found    │  │ Insert into DB          │
            │ Return 0         │  │ Return count            │
            └──────────────────┘  └──────┬──────────────────┘
                      │                   │
                      │                   ▼
                      │         ┌──────────────────────────┐
                      │         │ Show Notification        │
                      │         │ "Database updated:       │
                      │         │  X new entries added"    │
                      │         └──────┬───────────────────┘
                      │                │
                      │                ▼
                      │         ┌──────────────────────────┐
                      │         │ Update total_images      │
                      │         │ count in server          │
                      │         └──────┬───────────────────┘
                      │                │
                      └────────────────┴──────────┐
                                                  │
                                                  ▼
                                    ┌──────────────────────┐
                                    │ Update last_mtime    │
                                    │ Continue monitoring  │
                                    └──────────────────────┘
```

## Key Components

### 1. File Watcher (main_server.R)
- **Trigger**: Shiny reactive observer with `invalidateLater(5000)`
- **Function**: Monitors file modification time
- **Action**: Calls `update_annotations_table()` when file changes

### 2. Database Update (db_utils.R)
- **Function**: `update_annotations_table(conn, to_be_voted_images_file)`
- **Logic**: 
  1. Read file into data frame
  2. Query existing DB entries
  3. Compare using composite key (coordinates|REF|ALT)
  4. Insert only new entries
- **Return**: Integer count of new entries added

### 3. User Notification (main_server.R)
- **Success**: Shows message notification with count
- **Error**: Shows error notification with error message
- **Duration**: 5 seconds for success, 10 seconds for errors

## Duplicate Prevention Strategy

```
File Entry: chr1:1000|A|T
DB Entry:   chr1:1000|A|T
Comparison: MATCH → Skip (already exists)

File Entry: chr1:1000|G|C
DB Entry:   chr1:1000|A|T
Comparison: NO MATCH → Add (different mutation at same position)
```

## Error Handling

```
Try:
  ├─ Checkout DB connection from pool
  ├─ Call update_annotations_table()
  ├─ Show success notification (if new entries)
  └─ Update total_images count

Catch:
  ├─ Log error to console
  ├─ Show error notification to users
  └─ Continue monitoring (don't crash)

Finally:
  └─ Return connection to pool
```

## Timeline Example

```
Time    Action
------- ----------------------------------------------------------
00:00   App starts, file watcher initializes
00:00   Initial mtime: 2025-01-23 12:00:00
00:05   Check #1: mtime unchanged → continue
00:10   Check #2: mtime unchanged → continue
00:15   [User modifies file]
00:15   File mtime: 2025-01-23 12:15:30
00:20   Check #3: mtime changed → trigger update
00:20   Read file, compare with DB, find 3 new entries
00:20   Insert 3 entries into DB
00:20   Show notification: "Database updated: 3 new entries added"
00:20   Update total_images: 100 → 103
00:25   Check #4: mtime unchanged → continue
...
```

## Performance Characteristics

- **Check Frequency**: Every 5 seconds
- **Detection Latency**: 0-5 seconds (depends on when in cycle file is modified)
- **Update Time**: 
  - 1 entry: <1 second
  - 10 entries: <2 seconds
  - 100 entries: <5 seconds
- **Resource Usage**: 
  - Idle: Minimal (just mtime check)
  - Update: Moderate (DB query + insert operations)

## Integration Points

1. **Config System**: Uses `cfg$to_be_voted_images_file` from config.yaml
2. **Database Pool**: Uses existing `db_pool` for connections
3. **User Session**: Notifications shown to all active sessions
4. **Voting Module**: New entries automatically available for voting
5. **Total Images**: Server-wide count updated after successful update
