const fs = require('fs');
const path = require('path');

const dbPath = path.join(__dirname, '../../public/data/db.json');

// Ensure data directory exists
const dataDir = path.dirname(dbPath);
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}

// Default structure
let db = {
  monthlyUsage: {}, // { "userId_YYYY-MM": count }
  refillTickets: {} // { "userId": count }
};

// Load existing DB if available
if (fs.existsSync(dbPath)) {
  try {
    const raw = fs.readFileSync(dbPath, 'utf8');
    if (raw) {
      db = JSON.parse(raw);
    }
  } catch (e) {
    console.error('Failed to parse db.json, using default structure', e);
  }
}

// Ensure defaults
db.monthlyUsage = db.monthlyUsage || {};
db.refillTickets = db.refillTickets || {};

function saveDb() {
  try {
    fs.writeFileSync(dbPath, JSON.stringify(db, null, 2), 'utf8');
  } catch (e) {
    console.error('Failed to write db.json', e);
  }
}

function getMonthKey(userId) {
  const now = new Date();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  return `${userId}_${now.getFullYear()}-${month}`;
}

function getUsageCount(userId) {
  const key = getMonthKey(userId);
  return db.monthlyUsage[key] || 0;
}

function incrementUsage(userId) {
  const key = getMonthKey(userId);
  db.monthlyUsage[key] = (db.monthlyUsage[key] || 0) + 1;
  saveDb();
}

function getRefillTickets(userId) {
  return db.refillTickets[userId] || 0;
}

function addRefillTickets(userId, amount) {
  db.refillTickets[userId] = (db.refillTickets[userId] || 0) + amount;
  saveDb();
  return db.refillTickets[userId];
}

function consumeRefillTicket(userId) {
  if ((db.refillTickets[userId] || 0) > 0) {
    db.refillTickets[userId] -= 1;
    saveDb();
    return true;
  }
  return false;
}

module.exports = {
  getUsageCount,
  incrementUsage,
  getRefillTickets,
  addRefillTickets,
  consumeRefillTicket
};
