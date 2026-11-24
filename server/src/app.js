const express = require('express');
const cors = require('cors');
const helmet = require('helmet');

const app = express();

// Basic security headers
app.use(helmet());

// Development configuration.
// We will restrict allowed origins before production.
app.use(cors());

// Read JSON request bodies
app.use(express.json({ limit: '1mb' }));

// Test endpoint
app.get('/api/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    service: 'multi-vendor-api',
    message: 'Your backend is running!'
  });
});

// Unknown routes
app.use((req, res) => {
  res.status(404).json({
    error: 'Route not found'
  });
});

module.exports = app;