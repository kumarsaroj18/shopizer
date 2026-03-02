# Database Population Script

This script populates the Shopizer database using REST API endpoints.

## Prerequisites

- Shopizer application running (default: http://localhost:8080)
- Admin credentials configured (default: admin@shopizer.com / password)
- `curl` and `grep` installed

## Usage

### Basic Usage

```bash
./populate-db.sh
```

### Custom Configuration

```bash
# Custom base URL
BASE_URL=http://localhost:9090 ./populate-db.sh

# Custom store code
STORE=MYSTORE ./populate-db.sh

# Custom admin credentials
ADMIN_USER=admin@example.com ADMIN_PASS=mypassword ./populate-db.sh

# All together
BASE_URL=http://localhost:9090 STORE=MYSTORE ADMIN_USER=admin@example.com ADMIN_PASS=mypassword ./populate-db.sh
```

## What Gets Created

### Categories (3)
- Electronics
- Books
- Clothing

### Products (3)
- Premium Laptop (SKU: LAPTOP-001, $999.99)
- Smartphone Pro (SKU: PHONE-001, $699.99)
- Programming Guide (SKU: BOOK-001, $29.99)

### Customers (3)
- john.doe@example.com (password: password123)
- jane.smith@example.com (password: password123)
- bob.wilson@example.com (password: password123)

## API Endpoints Used

- `POST /api/v1/private/login` - Admin authentication
- `POST /api/v1/private/category` - Create categories
- `POST /api/v1/private/product` - Create products
- `POST /api/v1/customer/register` - Register customers

## Testing

After running the script, verify the data:

```bash
# List categories
curl http://localhost:8080/api/v1/category

# List products
curl http://localhost:8080/api/v1/products

# Login as customer
curl -X POST http://localhost:8080/api/v1/customer/login \
  -H "Content-Type: application/json" \
  -d '{"username":"john.doe@example.com","password":"password123"}'
```

## Troubleshooting

**Authentication fails:**
- Ensure the application is running
- Verify admin credentials match your configuration
- Check the default admin user was created during initialization

**Products/Categories not created:**
- Check the application logs for errors
- Verify the store code exists (default: DEFAULT)
- Ensure you have proper permissions

**Script hangs:**
- Check if the application is accessible at the BASE_URL
- Verify network connectivity
- Check application logs for errors
