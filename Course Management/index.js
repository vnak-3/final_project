const express = require('express');
const app = express();
const PORT = 3000;

const path = require('path');
app.use(express.static(path.join(__dirname, 'public')));

app.get('/', (req, res) => {
  res.json({
    message: 'Welcome to FoodExpress API',
    status: 'running',
    company: 'FoodExpress'
  });
});

app.get('/menu', (req, res) => {
  res.json({
    menu: [
      { id: 1, name: 'Burger', price: 5.99 },
      { id: 2, name: 'Pizza', price: 8.99 },
      { id: 3, name: 'Pasta', price: 6.99 }
    ]
  });
});

app.listen(PORT, () => {
  console.log(`FoodExpress API running on port ${PORT}`);
});