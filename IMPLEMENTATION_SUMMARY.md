# Multiple Customer Addresses Feature - Implementation Summary

## Overview
This implementation enables customers to have multiple billing and delivery addresses, replacing the previous single embedded address model.

## Phase 1: Failing Integration Test ✅
**File**: `sm-shop/src/test/java/com/salesmanager/test/shop/integration/customer/CustomerMultipleAddressesIntegrationTest.java`

Tests cover:
- Adding multiple billing addresses
- Adding multiple delivery addresses
- Mixed address types
- Updating addresses
- Rejecting identical billing/delivery addresses
- Ownership validation

## Phase 2: Implementation ✅

### 1. Domain Model Changes

#### New Enum
- **AddressType** (`sm-core-model/.../customer/AddressType.java`)
  - `BILLING`
  - `DELIVERY`

#### New Entity
- **CustomerAddress** (`sm-core-model/.../customer/CustomerAddress.java`)
  - `@ManyToOne` relationship to Customer
  - Contains: addressType, isDefault, firstName, lastName, company, address, city, postalCode, phone, stateProvince, country, zone, latitude, longitude
  - Auditable with creation/modification timestamps

#### Updated Entity
- **Customer** (`sm-core-model/.../customer/Customer.java`)
  - Added: `@OneToMany List<CustomerAddress> addresses`
  - Existing billing/delivery fields kept for backward compatibility

### 2. Repository Layer
- **CustomerAddressRepository** (`sm-core/.../repositories/customer/CustomerAddressRepository.java`)
  - `findByCustomerId(Long customerId)`
  - `findByCustomerIdAndAddressType(Long customerId, AddressType addressType)`
  - `findDefaultByCustomerIdAndType(Long customerId, AddressType addressType)`

### 3. Service Layer
- **CustomerAddressService** (`sm-core/.../services/customer/CustomerAddressService.java`)
- **CustomerAddressServiceImpl** (`sm-core/.../services/customer/CustomerAddressServiceImpl.java`)
  
**Validation Logic**:
- Ownership validation: Address must belong to customer
- Identical address validation: Billing and delivery addresses cannot be identical (based on address, city, postalCode, country)

### 4. DTOs
- **PersistableCustomerAddress** (`sm-shop-model/.../customer/address/PersistableCustomerAddress.java`)
  - Input DTO with validation annotations
- **ReadableCustomerAddress** (`sm-shop-model/.../customer/address/ReadableCustomerAddress.java`)
  - Output DTO

### 5. Facade Layer
- **CustomerAddressFacade** (`sm-shop-model/.../facade/customer/CustomerAddressFacade.java`)
- **CustomerAddressFacadeImpl** (`sm-shop/.../facade/customer/CustomerAddressFacadeImpl.java`)
  - Handles DTO-Entity conversion
  - Integrates with Country/Zone services
  - Transaction management

### 6. Controller Layer
- **CustomerAddressApi** (`sm-shop/.../api/v1/customer/CustomerAddressApi.java`)

**Endpoints**:
```
POST   /api/v1/auth/customer/address          - Create address
PUT    /api/v1/auth/customer/address/{id}     - Update address
DELETE /api/v1/auth/customer/address/{id}     - Delete address
GET    /api/v1/auth/customer/address/{id}     - Get address by ID
GET    /api/v1/auth/customer/addresses        - Get all addresses
```

All endpoints require authentication (`@PreAuthorize("hasRole('AUTH_CUSTOMER')")`).

### 7. Database Migration
**File**: `sm-shop/src/main/resources/db/migration/V1_1__customer_multiple_addresses.sql`

- Creates `CUSTOMER_ADDRESS` table
- Migrates existing billing addresses from `CUSTOMER` table
- Migrates existing delivery addresses from `CUSTOMER` table
- Creates indexes for performance
- **Backward compatible**: Existing `CUSTOMER` table columns preserved

## Phase 3: Unit Tests (TODO)
Unit tests should be added for:
- `CustomerAddressServiceImpl.validateAddress()`
- `CustomerAddressFacadeImpl` methods
- Edge cases and error scenarios

## Phase 4: Additional Integration Tests (TODO)
- HTTP 400 validation error responses
- HTTP 403/404 ownership validation
- Concurrent address modifications
- Default address handling

## Technical Highlights

### SOLID Principles
- **Single Responsibility**: Each class has one clear purpose
- **Open/Closed**: Extensible through interfaces
- **Liskov Substitution**: DTOs properly separated from entities
- **Interface Segregation**: Focused interfaces
- **Dependency Inversion**: Depends on abstractions (interfaces)

### Best Practices
- Transactional service layer
- Proper exception handling
- DTO-Entity separation
- Validation at service layer
- Security at controller layer
- Backward compatible migration

### Security
- Authentication required for all endpoints
- Ownership validation prevents unauthorized access
- Customer ID extracted from security context

## Testing the Feature

### 1. Run the failing test (before implementation)
```bash
mvn test -Dtest=CustomerMultipleAddressesIntegrationTest
```

### 2. Apply database migration
The migration will run automatically on application startup if using Flyway/Liquibase.

### 3. Test via API
```bash
# Login
curl -X POST http://localhost:8080/api/v1/customer/login \
  -H "Content-Type: application/json" \
  -d '{"username":"user@example.com","password":"password"}'

# Add billing address
curl -X POST http://localhost:8080/api/v1/auth/customer/address \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "addressType": "BILLING",
    "firstName": "John",
    "lastName": "Doe",
    "address": "123 Main St",
    "city": "New York",
    "postalCode": "10001",
    "country": "US"
  }'

# Get all addresses
curl -X GET http://localhost:8080/api/v1/auth/customer/addresses \
  -H "Authorization: Bearer {token}"
```

## Migration Notes

### Backward Compatibility
- Existing `CUSTOMER` table columns (BILLING_*, DELIVERY_*) are preserved
- Existing data is migrated to new `CUSTOMER_ADDRESS` table
- Old API endpoints continue to work (if not modified)

### Future Cleanup (Optional)
After ensuring all systems are updated:
1. Remove embedded `Billing` and `Delivery` fields from `Customer` entity
2. Drop columns from `CUSTOMER` table
3. Update old API endpoints to use new address system

## Files Created/Modified

### Created (13 files)
1. `AddressType.java` - Enum
2. `CustomerAddress.java` - Entity
3. `CustomerAddressRepository.java` - Repository
4. `CustomerAddressService.java` - Service interface
5. `CustomerAddressServiceImpl.java` - Service implementation
6. `PersistableCustomerAddress.java` - Input DTO
7. `ReadableCustomerAddress.java` - Output DTO
8. `CustomerAddressFacade.java` - Facade interface
9. `CustomerAddressFacadeImpl.java` - Facade implementation
10. `CustomerAddressApi.java` - REST Controller
11. `CustomerMultipleAddressesIntegrationTest.java` - Integration test
12. `V1_1__customer_multiple_addresses.sql` - Migration script
13. `IMPLEMENTATION_SUMMARY.md` - This file

### Modified (1 file)
1. `Customer.java` - Added addresses collection

## Next Steps
1. Run integration tests to verify functionality
2. Add unit tests for service layer
3. Add additional integration tests for error scenarios
4. Update API documentation (Swagger)
5. Consider adding default address management logic
6. Monitor performance with indexes
