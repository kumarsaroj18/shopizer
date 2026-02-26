# Test Fixes Summary

## Problem
Tests were failing due to duplicate key constraint violations in the H2 in-memory database. Multiple tests were creating entities with the same codes, causing SQL constraint violations.

## Root Cause
The integration tests share a single H2 database instance across all test methods. When tests create entities with hardcoded codes (e.g., "test-cat", "TESTTX", "customer1@test.com"), subsequent tests fail with duplicate key errors.

## Solution
Modified test code to use unique identifiers by appending timestamps or using modulo operations to generate unique codes for each test run.

## Files Modified

### 1. ServicesTestSupport.java
- **Change**: Updated `sampleProduct()` method to use the `code` parameter for category names instead of hardcoded "test-cat"
- **Impact**: Prevents duplicate category creation when multiple tests call this helper method

### 2. TaxRateIntegrationTest.java
- **manageTaxClass()**: Changed tax class code from "TESTTX" to "TX" + (timestamp % 100000)
- **manageTaxRates()**: Changed tax rate code from "taxcode1" to "TR" + (timestamp % 100000)
- **Reason**: Used modulo to keep codes short and avoid database column length constraints

### 3. OptinApiIntegrationTest.java
- **createOptin()**: Changed optin code from "PROMOTIONS" to "PROMOTIONS-" + timestamp
- **Impact**: Prevents duplicate optin entries

### 4. UserApiIntegrationTest.java
- **createUserChangePassword()**: Changed email from "test@test.com" to "test" + timestamp + "@test.com"
- **Impact**: Prevents duplicate user creation

### 5. CustomerRegistrationIntegrationTest.java
- **registerCustomer()**: Changed email from "customer1@test.com" to "customer" + timestamp + "@test.com"
- **Impact**: Prevents duplicate customer registration

### 6. MerchantStoreApiIntegrationTest.java
- **testCreateStore()**: Changed store code from "test" to "test-" + timestamp
- **Impact**: Prevents duplicate store creation

### 7. CategoryManagementAPIIntegrationTest.java
- **postCategory()**: Changed category code from "javascript" to "javascript-" + timestamp
- **postComplexCategory()**: Added timestamp to all category codes (diningroom, armoire, bench, livingroom, lounge)
- **manufacturerForItemsInCategory()**: Added timestamp to manufacturer and category codes
- **Impact**: Prevents duplicate category creation

### 8. ServicesTestSupport.java (Additional Fix)
- **sampleProduct()**: Modified to append timestamp to the code parameter for category, product, and SKU
- **sampleCart()**: Modified to append timestamp to the product code
- **Impact**: Ensures all test helper methods create unique entities across multiple test runs

### 9. ProductManagementAPIIntegrationTest.java (Additional Fix)
- **createProductWithCategory()**: Added timestamp to category code, product code, and SKU
- **Impact**: Prevents duplicate key violations when test runs multiple times

### 10. ProductV2ManagementAPIIntegrationTest.java (Additional Fix)
- **createProductWithCategory()**: Added timestamp to category code, product code, and product option codes (color, size, white, medium)
- **Impact**: Prevents duplicate key violations for categories, products, and product options

## Test Results

### Before Fixes
- Tests run: 34
- Failures: 12
- Errors: 6
- Skipped: 9
- **Total Issues: 18**

### After Initial Fixes
- Tests run: 34
- Failures: 5
- Errors: 4
- Skipped: 9
- **Total Issues: 9**

### After Complete Fixes
- Tests run: 34
- Failures: 0
- Errors: 0
- Skipped: 9
- **Total Issues: 0**

### Success Rate
- **100% of test failures resolved**
- **All 18 issues fixed**

## Tests Fixed ✅
1. MerchantStoreApiIntegrationTest.testCreateStore
2. CustomerRegistrationIntegrationTest.registerCustomer
3. OptinApiIntegrationTest.createOptin
4. UserApiIntegrationTest.createUserChangePassword
5. TaxRateIntegrationTest.manageTaxClass
6. TaxRateIntegrationTest.manageTaxRates
7. CategoryManagementAPIIntegrationTest.postCategory
8. CategoryManagementAPIIntegrationTest.postComplexCategory
9. CategoryManagementAPIIntegrationTest.manufacturerForItemsInCategory
10. ProductManagementAPIIntegrationTest.createProductWithCategory
11. ProductV2ManagementAPIIntegrationTest.createProductWithCategory
12. ShoppingCartAPIIntegrationTest.addToCart
13. ShoppingCartAPIIntegrationTest.addSecondToCart
14. ShoppingCartAPIIntegrationTest.addToWrongToCartId
15. ShoppingCartAPIIntegrationTest.updateMultiWCartId
16. ShoppingCartAPIIntegrationTest.updateMultiWZeroOnOneProd
17. ShoppingCartAPIIntegrationTest.deleteCartItem
18. ShoppingCartAPIIntegrationTest.deleteCartItemWithBody

## Remaining Issues
None - all tests are now passing!

## Recommendations for Remaining Issues

All issues have been resolved. The solution was to consistently use timestamps to generate unique codes for all entities (categories, products, manufacturers, tax classes, users, customers, stores, optins, and product options) across all test methods.

## Key Learnings

1. **Shared Database State**: Integration tests share a single H2 database instance, so unique identifiers are essential
2. **Timestamp Strategy**: Appending `System.currentTimeMillis()` to entity codes ensures uniqueness across test runs
3. **Helper Method Consistency**: Test helper methods like `sampleProduct()` must generate unique codes internally
4. **Composite Keys**: Some entities have composite unique constraints (e.g., MERCHANT_ID + CODE), requiring unique codes even within the same merchant

## Notes
- Avoided using `@DirtiesContext(classMode = ClassMode.AFTER_EACH_TEST_METHOD)` because it causes Infinispan cache lifecycle issues
- Used modulo operations for tax codes to avoid database column length constraints
- The IndexOutOfBoundsException errors are cascading failures from earlier test failures in the same test class
- **IMPORTANT**: Timestamp-based codes are ONLY used in test environment (H2 in-memory database)
- Production uses MySQL/PostgreSQL with separate configuration - test code never runs in production
- See [TEST_ISOLATION.md](TEST_ISOLATION.md) for details on test/production separation
