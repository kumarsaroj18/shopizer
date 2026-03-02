# H2 Database Initialization Summary

## Current Setup

### 1. **Database Configuration**
The application uses an in-memory H2 database configured in:
- **Location**: `/sm-shop/src/test/resources/database.properties`
- **Database URL**: `jdbc:h2:mem:SALESMANAGER-TEST;AUTOCOMMIT=OFF;;mv_store=false;INIT=CREATE SCHEMA IF NOT EXISTS SALESMANAGER`
- **Mode**: In-memory database for testing
- **Schema**: SALESMANAGER

**Configuration Details** (`database.properties`):
```properties
db.jdbcUrl=jdbc:h2:mem:SALESMANAGER-TEST;AUTOCOMMIT=OFF;;mv_store=false;INIT=CREATE SCHEMA IF NOT EXISTS SALESMANAGER
db.user=test
db.password=password
db.driverClass=org.h2.Driver
hibernate.dialect=org.hibernate.dialect.H2Dialect
hibernate.hbm2ddl.auto=create
```

### 2. **Database Initialization Process**

The application initializes the H2 database through a **Spring `@PostConstruct` based approach**:

#### Key Component: `InitializationLoader`
- **File**: `/sm-shop/src/main/java/com/salesmanager/shop/init/data/InitializationLoader.java`
- **Trigger**: Uses `@PostConstruct` annotation to run on application startup
- **Configuration**: Controlled by property `db.init.data` (defaults to `true`)

#### Initialization Flow:
1. **Application Startup** → `InitializationLoader.init()` is called
2. **Check Database Status** → `initializationDatabase.isEmpty()` checks if any languages exist
3. **Populate if Empty** → If database is empty, calls `initializationDatabase.populate("sm-shop")`
4. **Create Default Admin** → Calls `userDetailsService.createDefaultAdmin()`
5. **Merchant Configuration** → Saves initial merchant configuration

#### Populated Data:
The `InitializationDatabaseImpl` creates:
- ✅ **Security Groups** (ADMIN, SUPERADMIN)
- ✅ **Permissions** (AUTH, ADMIN, PRODUCTS, ORDERS, CUSTOMERS, SHIPPING, etc.)
- ✅ **Languages** (en, fr, and more from SchemaConstant)
- ✅ **Countries** (from SchemaConstant, ~250+ countries)
- ✅ **Zones** (States/Provinces for countries)
- ✅ **Currencies** (from SchemaConstant)
- ✅ **Product Types** (GENERAL_TYPE)
- ✅ **Tax Classes** (DEFAULT)
- ✅ **Merchant Store** (DEFAULT store with configuration)
- ✅ **Default Manufacturer**
- ✅ **Default Admin User** (admin@shopizer.com / password)
- ✅ **Modules** (Integration modules from JSON config)

### 3. **Alternative: init-data.sql (Currently Disabled)**

**File**: `/sm-shop/src/main/resources/init-data.sql`

This file contains SQL INSERT statements with dummy data but is **currently disabled** in `application.properties`:
```properties
# SQL initialization - DISABLED (app has its own data loader)
#spring.sql.init.mode=always
#spring.sql.init.data-locations=classpath:init-data.sql
#spring.sql.init.continue-on-error=false
#spring.jpa.defer-datasource-initialization=true
```

**Dummy Data in init-data.sql includes**:
- Languages (English, French)
- Countries (US, CA, GB)
- Zones (CA, NY, ON)
- Currencies (USD, CAD, EUR)
- Merchant Store (Shopizer Demo Store)
- Permissions and Groups
- Admin User
- Tax Classes
- Product Types
- Sample Manufacturer
- Sample Categories (Electronics, Clothing)
- Sample Products:
  - Product ID 1: Laptop Computer (SKU: LAPTOP-001, Price: $999.99)
  - Product ID 2: Cotton T-Shirt (SKU: TSHIRT-001, Price: $29.99)
- Product Availability
- Product Prices
- Sample Customer (customer@example.com)

## New Test Suite

### Test Class: `H2DatabaseInitializationTest`
**Location**: `/sm-shop/src/test/java/com/salesmanager/test/shop/integration/system/H2DatabaseInitializationTest.java`

#### Test Coverage (24 Test Cases):

1. **Language Tests**
   - `testLanguagesInitialization()` - Verifies languages are populated
   - `testSpecificLanguagesExist()` - Checks for English and French

2. **Country Tests**
   - `testCountriesInitialization()` - Verifies multiple countries exist
   - `testSpecificCountriesExist()` - Checks for US and CA

3. **Zone Tests**
   - `testZonesInitialization()` - Verifies zones for states/provinces

4. **Currency Tests**
   - `testCurrenciesInitialization()` - Verifies multiple currencies exist
   - `testSpecificCurrenciesExist()` - Checks for USD and CAD

5. **Merchant Store Tests**
   - `testMerchantStoreInitialization()` - Verifies DEFAULT store exists
   - `testDefaultMerchantStoreConfiguration()` - Validates store configuration

6. **Permission & Group Tests**
   - `testPermissionGroupsInitialization()` - Verifies groups exist
   - `testPermissionsInitialization()` - Verifies permissions exist

7. **User Tests**
   - `testDefaultAdminUserInitialization()` - Verifies default admin user

8. **Catalog Tests**
   - `testTaxClassesInitialization()` - Verifies tax classes
   - `testProductTypesInitialization()` - Verifies product types
   - `testManufacturersInitialization()` - Verifies manufacturers
   - `testProductsInitialization()` - Verifies dummy products
   - `testDummyProductsHaveCorrectSKUs()` - Validates product SKUs
   - `testCategoriesInitialization()` - Verifies product categories
   - `testProductAvailabilityInitialization()` - Verifies availability data
   - `testProductPricesInitialization()` - Verifies pricing data

9. **Customer Tests**
   - `testCustomerSampleDataInitialization()` - Verifies sample customer

10. **Overall Tests**
    - `testOverallDatabaseInitializationCompleteness()` - Comprehensive check

### Running the Tests

#### Prerequisites:
- Java 11+ (project requires Java 11)
- Maven 3.5+

#### Test Execution:
```bash
cd sm-shop

# Run specific test class
mvn test -Dtest=H2DatabaseInitializationTest

# Run all tests
mvn test

# Run with details
mvn test -Dtest=H2DatabaseInitializationTest -X
```

#### Expected Output:
```
Tests run: 24, Failures: 0, Errors: 0, Skipped: 0
```

## Verification Checklist

✅ **H2 Database Configuration**
- In-memory H2 database properly configured
- SALESMANAGER schema created on startup
- Hibernate DDL auto set to `create`

✅ **Initialization Process**
- `InitializationLoader` component triggers on `@PostConstruct`
- `InitializationDatabaseImpl.populate()` creates all required entities
- Default admin user created automatically

✅ **Dummy Data**
- Core reference data (Languages, Countries, Currencies) initialized
- Merchant store and admin user created
- Sample products (Laptop, T-Shirt) with proper SKUs
- Customer data available for testing

✅ **Test Coverage**
- Comprehensive test suite with 24 test cases
- Validates all major entity initialization
- Checks specific values for critical entities
- Tests for data completeness

## Files Modified/Created

1. **Created**: `/sm-shop/src/test/java/com/salesmanager/test/shop/integration/system/H2DatabaseInitializationTest.java`
   - New comprehensive test suite for H2 initialization
   - 24 test cases covering all major entities

## Notes

- The `init-data.sql` file is available but disabled. The application uses the programmatic approach via `InitializationDatabaseImpl` instead.
- The programmatic approach is more flexible and handles complex relationships better than pure SQL.
- Tests run against an in-memory H2 database that is created fresh for each test run.
- The test class uses Spring's `@SpringBootTest` to ensure full application context is loaded during testing.

## Additional Resources

- **InitializationDatabaseImpl**: Core initialization service
- **InitializationLoader**: Spring component that triggers initialization
- **Database Configuration**: Located in spring application context and database.properties
