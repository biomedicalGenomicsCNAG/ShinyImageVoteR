# B1MG Voting App

Voting application that allows users to vote on different B1MG variants
Users get presented a randomly picked image of a B1MG variant and can vote for it.

[![Convert-Pheno-UI](docs/ui.gif)](docs/ui.gif)

## Required external services
- minio S3 (https://github.com/minio/minio)

## Development Prerequisites
- node (developed with v22.13.0)
- npm (developed with v10.9.2)

## Quickstart
1. Start the node server
```bash
cd server
npm install
node run.js
```

2. Open a new terminal to start the react application
```bash
cd ui
npm install
npm run dev
```
3. Navigate to http://localhost:5173

### AUTHOR

Written by Ivo Christopher Leist, PhD student at CNAG [https://www.cnag.eu](https://www.cnag.eu).

### COPYRIGHT AND LICENSE

Copyright (C) 2022-2023, Ivo Christopher Leist - CNAG.

GPLv3 - GNU General Public License v3.0