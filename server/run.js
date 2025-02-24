import express from "express";
import { v4 as uuidv4 } from "uuid";

import Database from 'better-sqlite3';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const db = new Database(path.join(__dirname, './db.sqlite'));

// Create tables if they don't exist
db.exec(`
  CREATE TABLE IF NOT EXISTS images (
    id TEXT PRIMARY KEY,
    url TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS votes (
    id TEXT PRIMARY KEY,
    image_id TEXT NOT NULL,
    rating INTEGER CHECK(rating BETWEEN 1 AND 5) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (image_id) REFERENCES images(id) ON DELETE CASCADE
  );

  CREATE INDEX IF NOT EXISTS idx_votes_image_id ON votes(image_id);
`);

// Insert sample S3 images if they don't exist
const sampleImages = [
  { id: '1', url: 'https://omicsdm.cnag.dev/bucketdevelomicsdm/alex-perez-e6fwIVD0FYs-unsplash.jpg' },
  { id: '2', url: 'https://omicsdm.cnag.dev/bucketdevelomicsdm/mark-boss-vw9ARuUnkVY-unsplash.jpg' },
  { id: '3', url: 'https://omicsdm.cnag.dev/bucketdevelomicsdm/michael-willoughby-050ZRJrFYZA-unsplash.jpg' },
];

const stmt = db.prepare('INSERT OR IGNORE INTO images (id, url) VALUES (?, ?)');
for (const image of sampleImages) {
  console.log(image.id, image.url);
  stmt.run(image.id, image.url);
}

const totalImages = db.prepare('SELECT COUNT(*) as count FROM images').get();
console.log(`Total images in database: ${totalImages.count}`);

const app = express();
app.use(express.json());

// Get a random unvoted image
app.get('/api/images/next', (req, res) => {
  const image = db.prepare(`
    SELECT i.* 
    FROM images i
    LEFT JOIN votes v ON i.id = v.image_id
    GROUP BY i.id
    ORDER BY COUNT(v.id), RANDOM()
    LIMIT 1
  `).get();

  console.log("unvoted image", image);

  if (!image) {
    res.status(404).json({ error: 'No more images to vote on' });
    return;
  }

  res.json(image);
});

// Add vote
app.post('/api/votes', (req, res) => {
  const { image_id, rating } = req.body;
  const id = uuidv4();

  try {
    if (rating < 1 || rating > 5) {
      throw new Error('Rating must be between 1 and 5');
    }

    db.prepare('INSERT INTO votes (id, image_id, rating) VALUES (?, ?, ?)')
      .run(id, image_id, rating);
    res.json({ id, image_id, rating });
  } catch (error) {
    res.status(500).json({ error: 'Failed to add vote' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});