import urllib.request
import json

url = 'http://localhost:3000/api/orders'
headers = {'Content-Type': 'application/json'}

orders = [
    {
        "order_number": "ONL-8899",
        "order_type": "delivery",
        "order_source": "website",
        "customer_name": "Ali Khan",
        "customer_phone": "+92 300 9876543",
        "delivery_address": "Sector G-13/4, Islamabad",
        "subtotal": 2500,
        "delivery_fee": 200,
        "grand_total": 2700,
        "is_paid": False,
        "payment_method": "cash",
        "items": [
            {
                "item_name": "Classic Pepperoni",
                "quantity": 2,
                "unit_price": 1250,
                "total_price": 2500,
                "selected_size": "Large"
            }
        ]
    },
    {
        "order_number": "ONL-8900",
        "order_type": "delivery",
        "order_source": "mobile_app",
        "customer_name": "Sara Ahmed",
        "customer_phone": "+92 321 1234567",
        "delivery_address": "F-8 Markaz, Islamabad",
        "subtotal": 800,
        "delivery_fee": 100,
        "grand_total": 900,
        "is_paid": True,
        "payment_method": "card",
        "items": [
            {
                "item_name": "Chocolate Lava Cake",
                "quantity": 2,
                "unit_price": 400,
                "total_price": 800,
                "selected_size": "Regular"
            }
        ]
    }
]

for order in orders:
    req = urllib.request.Request(url, data=json.dumps(order).encode('utf-8'), headers=headers)
    try:
        with urllib.request.urlopen(req) as response:
            print(f"Created order {order['order_number']}")
    except Exception as e:
        print(f"Error creating order {order['order_number']}: {e}")
