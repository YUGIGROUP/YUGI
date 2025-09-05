const express = require('express');
const router = express.Router();

// Basic users route - placeholder for now
router.get('/', (req, res) => {
  res.json({ message: 'Users route working' });
});

module.exports = router; 