const http = require('http');

http.get('http://localhost:3000/api/orders', (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    let orders = JSON.parse(data);
    if (!Array.isArray(orders)) {
        console.log("API returned object:", Object.keys(orders));
        if (orders.data) orders = orders.data;
    }
    if (Array.isArray(orders)) {
      const onlineOrders = orders.filter(j => 
          (j.order_source && j.order_source.toLowerCase().includes('online')) ||
          (j.order_type && j.order_type.toLowerCase().includes('delivery')) ||
          (j.order_type && j.order_type.toLowerCase().includes('online'))
      );
      console.log("Total Orders:", orders.length);
      console.log("Online Orders matched:", onlineOrders.length);
    } else {
      console.log("Still not an array!");
    }
  });
}).on('error', (e) => {
  console.error("Got error: " + e.message);
});
