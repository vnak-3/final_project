const express = require('express');
const path = require('path');
const client = require('prom-client');

const app = express();
const PORT = 3000;

// Collect default Node.js metrics
client.collectDefaultMetrics();

// Custom request counter
const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

// Custom request duration metric
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.3, 0.5, 1, 2, 5]
});

// Middleware to track requests
app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();

  res.on('finish', () => {
    const route = req.route ? req.route.path : req.path;

    httpRequestsTotal.inc({
      method: req.method,
      route: route,
      status_code: res.statusCode
    });

    end({
      method: req.method,
      route: route,
      status_code: res.statusCode
    });
  });

  next();
});

app.use(express.static(path.join(__dirname, 'public')));

app.get('/api/status', (req, res) => {
  res.json({
    message: 'AUPP Learning Platform API is running',
    status: 'healthy',
    service: 'aupp-lms'
  });
});

// Prometheus metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});

app.listen(PORT, () => {
  console.log(`AUPP LMS app running on port ${PORT}`);
});