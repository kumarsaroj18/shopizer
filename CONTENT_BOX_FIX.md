# Fix for Missing headerMessage Content Box

## Problem
API endpoint `/api/v1/content/boxes/headerMessage/?lang=en` was returning 404 error:
```
Resource not found [headerMessage] for store [DEFAULT]
```

## Root Cause
The `headerMessage` content box was not being created during database initialization.

## Solution
Added initialization for default content boxes in `InitializationDatabaseImpl.java`:

1. Injected `ContentService`
2. Added `createDefaultContent()` method that creates the `headerMessage` content box
3. Called this method during database population

## Content Box Created
- **Code**: headerMessage
- **Type**: BOX
- **Name**: Header Message
- **Description**: Welcome to our store
- **Visible**: true
- **Language**: English (en)

## How to Apply

### For New Database
The content box will be created automatically when the application starts with `db.init.data=true` (default).

### For Existing Database
You have two options:

#### Option 1: Reset Database (Development Only)
```bash
# Drop and recreate database
mysql -u root -p
DROP DATABASE SALESMANAGER;
CREATE DATABASE SALESMANAGER;
GRANT ALL ON SALESMANAGER.* TO shopizer;
FLUSH PRIVILEGES;
exit

# Restart application - initialization will run
```

#### Option 2: Create Manually via API
```bash
curl -X POST http://localhost:8080/api/v1/private/content/box \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "code": "headerMessage",
    "visible": true,
    "contentType": "BOX",
    "descriptions": [{
      "language": "en",
      "name": "Header Message",
      "description": "Welcome to our store"
    }]
  }'
```

## Testing
After applying the fix, test the endpoint:
```bash
curl http://localhost:8080/api/v1/content/boxes/headerMessage/?lang=en
```

Expected response:
```json
{
  "code": "headerMessage",
  "name": "Header Message",
  "description": "Welcome to our store",
  "visible": true
}
```

## Files Modified
- `sm-core/src/main/java/com/salesmanager/core/business/services/reference/init/InitializationDatabaseImpl.java`
  - Added ContentService injection
  - Added createDefaultContent() method
  - Added imports for Content, ContentDescription, ContentType
