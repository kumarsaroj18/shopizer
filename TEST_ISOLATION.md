# Test Isolation and Data Management

## Overview
This document explains how tests are isolated from production and why timestamp-based unique codes are used in tests.

## Test vs Production Database

### Test Environment
- **Database**: H2 in-memory (`jdbc:h2:mem:SALESMANAGER-TEST`)
- **Configuration**: `sm-shop/src/test/resources/database.properties`
- **Schema**: Created fresh for each test run (`hibernate.hbm2ddl.auto=create`)
- **Data**: Temporary, destroyed after tests complete

### Production Environment
- **Database**: MySQL/PostgreSQL
- **Configuration**: `sm-shop/src/main/resources/profiles/*/database.properties`
- **Schema**: Updated incrementally (`hibernate.hbm2ddl.auto=update`)
- **Data**: Persistent

## Why Timestamps in Test Codes?

Integration tests share a single H2 database instance across all test methods. Without unique identifiers, tests fail with duplicate key constraint violations.

### Example:
```java
// Test helper method
protected ReadableProduct sampleProduct(String code) {
    String uniqueCode = code + "-" + System.currentTimeMillis();
    // Creates category and product with unique codes
}
```

This ensures:
1. Each test run creates unique entities
2. Tests can run in any order
3. No duplicate key violations
4. Test data doesn't persist (H2 in-memory)

## Production Data Safety

### Safeguards:
1. **Separate databases**: Tests use H2, production uses MySQL/PostgreSQL
2. **Test-only code**: Helper methods in `ServicesTestSupport` are in `src/test/` directory
3. **Profile isolation**: Test profile uses different database configuration
4. **Init data flag**: Production can disable default data with `db.init.data=false`

### If You See Junk Data in Production:

This indicates one of these issues:
1. Tests were accidentally run against production database (wrong configuration)
2. Someone manually created test data in production
3. Development/staging data was migrated to production

### Prevention:
- Never run tests with production database credentials
- Use separate databases for dev/test/prod
- Set `db.init.data=false` in production to prevent default data creation
- Review database credentials in configuration files

## Running Tests Safely

```bash
# Tests automatically use H2 in-memory database
cd sm-shop
../mvnw test

# Verify test configuration
cat src/test/resources/database.properties
```

## Cleaning Production Database

If junk data exists in production, manually clean it:

```sql
-- Identify test data (look for timestamp patterns)
SELECT * FROM CATEGORY WHERE CODE LIKE '%-1%';
SELECT * FROM PRODUCT WHERE SKU LIKE '%-1%';

-- Delete test data (BE CAREFUL!)
DELETE FROM PRODUCT_CATEGORY WHERE CATEGORY_ID IN (SELECT CATEGORY_ID FROM CATEGORY WHERE CODE LIKE '%-1%');
DELETE FROM CATEGORY WHERE CODE LIKE '%-1%';
-- etc.
```

**WARNING**: Always backup production database before deleting data!
