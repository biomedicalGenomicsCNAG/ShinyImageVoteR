## Quickstart
1. Start the node server
```bash
cd server
npm install
node run.js
```

Alternatively to the node server, you can use a R server:
```bash
cd server/plumber
R -e "renv::restore()"
Rscript run.R
```