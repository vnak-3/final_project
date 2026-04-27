const express = require('express');
const app = express();
const PORT = 3000;
const path = require('path');

app.use(express.static(path.join(__dirname, 'public')));

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

app.get('/api/menu', (req, res) => {
  res.json({
    menu: [
      { id: 1, name: 'Burger', price: 5.99 },
      { id: 2, name: 'Pizza', price: 8.99 },
      { id: 3, name: 'Pasta', price: 6.99 }
    ]
  });
});

app.get('/api/status', (req, res) => {
  res.json({
    message: 'Welcome to AUPP Learning Platform API',
    status: 'running',
    company: 'AUPP'
  });
});

app.listen(PORT, () => {
  console.log(`Course Management API running on port ${PORT}`);
});