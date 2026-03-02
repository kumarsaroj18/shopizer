# Multiple Customer Addresses Feature - Technical Documentation

## Feature Overview
Enable customers to manage multiple billing and delivery addresses instead of the previous limitation of one billing and one delivery address per customer.

---

## Architecture Changes

### 1. Data Model Changes

#### New Enum: `AddressType`
**Location**: `sm-core-model/src/main/java/com/salesmanager/core/model/customer/AddressType.java`

```java
public enum AddressType {
    BILLING,
    DELIVERY
}
```

**Purpose**: Type-safe enumeration to distinguish between billing and delivery addresses.

---

#### New Entity: `CustomerAddress`
**Location**: `sm-core-model/src/main/java/com/salesmanager/core/model/customer/CustomerAddress.java`

**Relationship**: `@ManyToOne` with `Customer`

**Key Fields**:
| Field | Type | Description |
|-------|------|-------------|
| `id` | Long | Primary key |
| `customer` | Customer | Reference to customer (FK) |
| `addressType` | AddressType | BILLING or DELIVERY |
| `isDefault` | boolean | Flag for default address |
| `firstName` | String | Required |
| `lastName` | String | Required |
| `address` | String | Street address |
| `city` | String | City |
| `postalCode` | String | Postal/ZIP code |
| `phone` | String | Phone number |
| `stateProvince` | String | State or province |
| `country` | Country | FK to Country |
| `zone` | Zone | FK to Zone |
| `latitude` | String | GPS coordinate |
| `longitude` | String | GPS coordinate |

**Annotations**:
- `@Entity` - JPA entity
- `@Table(name = "CUSTOMER_ADDRESS")` - Table mapping
- Implements `Auditable` - Automatic audit trail

---

#### Updated Entity: `Customer`
**Location**: `sm-core-model/src/main/java/com/salesmanager/core/model/customer/Customer.java`

**Changes**:
```java
// Added field
@OneToMany(mappedBy = "customer", cascade = CascadeType.ALL, orphanRemoval = true)
private List<CustomerAddress> addresses = new ArrayList<CustomerAddress>();

// Added methods
public List<CustomerAddress> getAddresses()
public void setAddresses(List<CustomerAddress> addresses)
```

**Note**: Existing `@Embedded Billing` and `@Embedded Delivery` fields retained for backward compatibility.

---

### 2. Repository Layer

#### New Repository: `CustomerAddressRepository`
**Location**: `sm-core/src/main/java/com/salesmanager/core/business/repositories/customer/CustomerAddressRepository.java`

**Interface**: Extends `JpaRepository<CustomerAddress, Long>`

**Methods**:
```java
List<CustomerAddress> findByCustomerId(Long customerId)
List<CustomerAddress> findByCustomerIdAndAddressType(Long customerId, AddressType addressType)
CustomerAddress findDefaultByCustomerIdAndType(Long customerId, AddressType addressType)
```

**Purpose**: Data access layer for customer addresses with custom queries.

---

### 3. Service Layer

#### New Service Interface: `CustomerAddressService`
**Location**: `sm-core/src/main/java/com/salesmanager/core/business/services/customer/CustomerAddressService.java`

**Extends**: `SalesManagerEntityService<Long, CustomerAddress>`

**Methods**:
```java
List<CustomerAddress> getByCustomer(Long customerId)
List<CustomerAddress> getByCustomerAndType(Long customerId, AddressType addressType)
CustomerAddress getDefaultAddress(Long customerId, AddressType addressType)
void validateAddress(CustomerAddress address, Long customerId) throws ServiceException
```

---

#### New Service Implementation: `CustomerAddressServiceImpl`
**Location**: `sm-core/src/main/java/com/salesmanager/core/business/services/customer/CustomerAddressServiceImpl.java`

**Annotation**: `@Service("customerAddressService")`

**Key Logic**:

##### Validation Rules
1. **Ownership Validation**:
   ```java
   // Ensures address belongs to the customer
   if (existing == null || !existing.getCustomer().getId().equals(customerId)) {
       throw new ServiceException("Address does not belong to customer");
   }
   ```

2. **Identical Address Prevention**:
   ```java
   // Prevents identical billing and delivery addresses
   // Compares: address, city, postalCode, country
   private boolean areAddressesIdentical(CustomerAddress addr1, CustomerAddress addr2)
   ```

**Transaction Management**: All write operations are `@Transactional`

---

### 4. Data Transfer Objects (DTOs)

#### Input DTO: `PersistableCustomerAddress`
**Location**: `sm-shop-model/src/main/java/com/salesmanager/shop/model/customer/address/PersistableCustomerAddress.java`

**Validation Annotations**:
- `@NotNull` on `addressType`
- `@NotEmpty` on `firstName`, `lastName`

**Purpose**: Request payload for creating/updating addresses

---

#### Output DTO: `ReadableCustomerAddress`
**Location**: `sm-shop-model/src/main/java/com/salesmanager/shop/model/customer/address/ReadableCustomerAddress.java`

**Purpose**: Response payload for address data

**Difference from Input**: 
- No validation annotations
- Includes `id` field
- Country/Zone returned as codes (not full objects)

---

### 5. Facade Layer

#### New Facade Interface: `CustomerAddressFacade`
**Location**: `sm-shop-model/src/main/java/com/salesmanager/shop/store/facade/customer/CustomerAddressFacade.java`

**Methods**:
```java
ReadableCustomerAddress create(PersistableCustomerAddress, Long customerId, MerchantStore)
ReadableCustomerAddress update(Long addressId, PersistableCustomerAddress, Long customerId, MerchantStore)
void delete(Long addressId, Long customerId)
ReadableCustomerAddress getById(Long addressId, Long customerId)
List<ReadableCustomerAddress> getByCustomer(Long customerId)
```

---

#### New Facade Implementation: `CustomerAddressFacadeImpl`
**Location**: `sm-shop/src/main/java/com/salesmanager/shop/store/facade/customer/CustomerAddressFacadeImpl.java`

**Annotation**: `@Service("customerAddressFacade")`

**Dependencies**:
- `CustomerAddressService` - Core business logic
- `CustomerService` - Customer lookup
- `CountryService` - Country code resolution
- `ZoneService` - Zone code resolution

**Responsibilities**:
1. DTO ↔ Entity conversion
2. Business rule enforcement
3. Exception translation (ServiceException → ServiceRuntimeException)
4. Transaction coordination

**Key Methods**:
- `toEntity()` - Converts DTO to entity, resolves country/zone
- `toReadable()` - Converts entity to DTO

---

### 6. REST API Layer

#### New Controller: `CustomerAddressApi`
**Location**: `sm-shop/src/main/java/com/salesmanager/shop/store/api/v1/customer/CustomerAddressApi.java`

**Base Path**: `/api/v1`

**Security**: All endpoints require `@PreAuthorize("hasRole('AUTH_CUSTOMER')")`

**Endpoints**:

| Method | Path | Description | Status Codes |
|--------|------|-------------|--------------|
| POST | `/auth/customer/address` | Create new address | 201, 400, 401 |
| PUT | `/auth/customer/address/{id}` | Update address | 200, 400, 404 |
| DELETE | `/auth/customer/address/{id}` | Delete address | 204, 404 |
| GET | `/auth/customer/address/{id}` | Get address by ID | 200, 404 |
| GET | `/auth/customer/addresses` | Get all addresses | 200 |

**Request/Response Examples**:

##### Create Address (POST)
```json
{
  "addressType": "BILLING",
  "firstName": "John",
  "lastName": "Doe",
  "address": "123 Main St",
  "city": "New York",
  "postalCode": "10001",
  "country": "US",
  "phone": "+1-555-0100",
  "isDefault": true
}
```

##### Response (201 Created)
```json
{
  "id": 1,
  "addressType": "BILLING",
  "firstName": "John",
  "lastName": "Doe",
  "address": "123 Main St",
  "city": "New York",
  "postalCode": "10001",
  "country": "US",
  "phone": "+1-555-0100",
  "isDefault": true
}
```

**Authentication**: Customer ID extracted from `@RequestAttribute("CUSTOMER")`

---

### 7. Database Changes

#### Migration Script
**Location**: `sm-shop/src/main/resources/db/migration/V1_1__customer_multiple_addresses.sql`

**Schema Changes**:

##### New Table: `CUSTOMER_ADDRESS`
```sql
CREATE TABLE CUSTOMER_ADDRESS (
    ADDRESS_ID BIGINT PRIMARY KEY,
    CUSTOMER_ID BIGINT NOT NULL,
    ADDRESS_TYPE VARCHAR(20) NOT NULL,
    IS_DEFAULT BOOLEAN DEFAULT FALSE,
    FIRST_NAME VARCHAR(64) NOT NULL,
    LAST_NAME VARCHAR(64) NOT NULL,
    COMPANY VARCHAR(100),
    ADDRESS VARCHAR(256),
    CITY VARCHAR(100),
    POSTAL_CODE VARCHAR(20),
    PHONE VARCHAR(32),
    STATE_PROVINCE VARCHAR(100),
    COUNTRY_ID BIGINT,
    ZONE_ID BIGINT,
    LATITUDE VARCHAR(100),
    LONGITUDE VARCHAR(100),
    DATE_CREATED TIMESTAMP,
    DATE_MODIFIED TIMESTAMP,
    UPDT_ID VARCHAR(20),
    CONSTRAINT FK_CUSTOMER_ADDRESS_CUSTOMER 
        FOREIGN KEY (CUSTOMER_ID) REFERENCES CUSTOMER(CUSTOMER_ID) ON DELETE CASCADE,
    CONSTRAINT FK_CUSTOMER_ADDRESS_COUNTRY 
        FOREIGN KEY (COUNTRY_ID) REFERENCES COUNTRY(COUNTRY_ID),
    CONSTRAINT FK_CUSTOMER_ADDRESS_ZONE 
        FOREIGN KEY (ZONE_ID) REFERENCES ZONE(ZONE_ID)
);
```

##### Indexes
```sql
CREATE INDEX IDX_CUSTOMER_ADDRESS_CUSTOMER ON CUSTOMER_ADDRESS(CUSTOMER_ID);
CREATE INDEX IDX_CUSTOMER_ADDRESS_TYPE ON CUSTOMER_ADDRESS(ADDRESS_TYPE);
CREATE INDEX IDX_CUSTOMER_ADDRESS_DEFAULT ON CUSTOMER_ADDRESS(CUSTOMER_ID, ADDRESS_TYPE, IS_DEFAULT);
```

##### Data Migration
- Existing billing addresses migrated from `CUSTOMER.BILLING_*` columns
- Existing delivery addresses migrated from `CUSTOMER.DELIVERY_*` columns
- Migrated addresses marked as `IS_DEFAULT = TRUE`

**Backward Compatibility**: Original `CUSTOMER` table columns preserved.

---

### 8. Testing

#### Integration Test
**Location**: `sm-shop/src/test/java/com/salesmanager/test/shop/integration/customer/CustomerMultipleAddressesIntegrationTest.java`

**Test Coverage**:
1. `testAddMultipleBillingAddresses()` - Verify multiple billing addresses
2. `testAddMultipleDeliveryAddresses()` - Verify multiple delivery addresses
3. `testAddMixedAddresses()` - Verify both types coexist
4. `testUpdateAddress()` - Verify address updates
5. `testRejectIdenticalBillingAndDeliveryAddresses()` - Verify validation

**Test Setup**:
- Uses `@SpringBootTest` with random port
- Creates authenticated customer
- Uses `RestTemplate` for API calls

---

## Design Patterns Used

### 1. Repository Pattern
- `CustomerAddressRepository` abstracts data access
- Decouples business logic from persistence

### 2. Facade Pattern
- `CustomerAddressFacade` provides simplified interface
- Coordinates multiple services
- Handles DTO conversions

### 3. DTO Pattern
- Separates API contracts from domain model
- `PersistableCustomerAddress` for input
- `ReadableCustomerAddress` for output

### 4. Service Layer Pattern
- Business logic in `CustomerAddressService`
- Transaction management
- Validation rules

---

## Security Considerations

### Authentication
- All endpoints require JWT authentication
- Role: `AUTH_CUSTOMER`

### Authorization
- Customer ID from security context
- Ownership validation on all operations
- Prevents cross-customer access

### Validation
- Input validation via Bean Validation (`@NotNull`, `@NotEmpty`)
- Business rule validation in service layer
- SQL injection prevention via JPA/Hibernate

---

## Performance Considerations

### Database Indexes
1. `IDX_CUSTOMER_ADDRESS_CUSTOMER` - Fast customer lookup
2. `IDX_CUSTOMER_ADDRESS_TYPE` - Filter by address type
3. `IDX_CUSTOMER_ADDRESS_DEFAULT` - Composite index for default address queries

### Lazy Loading
- `@ManyToOne(fetch = FetchType.LAZY)` on Country and Zone
- Prevents N+1 query problems

### Cascade Operations
- `CascadeType.ALL` on Customer → CustomerAddress
- `orphanRemoval = true` - Automatic cleanup

---

## Error Handling

### Exception Hierarchy
```
ServiceException (checked)
  ↓
ServiceRuntimeException (unchecked)
  ↓
ResourceNotFoundException (404)
```

### HTTP Status Codes
- `200 OK` - Successful GET/PUT
- `201 Created` - Successful POST
- `204 No Content` - Successful DELETE
- `400 Bad Request` - Validation failure
- `401 Unauthorized` - Authentication required
- `404 Not Found` - Resource not found

---

## Backward Compatibility

### Preserved Elements
1. `Customer.billing` field (embedded)
2. `Customer.delivery` field (embedded)
3. Database columns: `BILLING_*`, `DELIVERY_*`

### Migration Strategy
1. **Phase 1**: Deploy new code with both systems
2. **Phase 2**: Migrate clients to new API
3. **Phase 3** (Future): Remove old fields

---

## Configuration

### Required Dependencies
```xml
<!-- Already present in project -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-jpa</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-security</artifactId>
</dependency>
```

### No Additional Configuration Required
- Uses existing database connection
- Uses existing security configuration
- Uses existing transaction management

---

## API Documentation (Swagger)

### Annotations Used
- `@Api(tags = {"Customer Address Management"})`
- `@ApiOperation` - Endpoint descriptions
- `@ApiResponses` - Response codes
- `@ApiModelProperty` - Field descriptions

**Access**: `http://localhost:8080/swagger-ui.html`

---

## Monitoring & Logging

### Log Points
1. Service layer validation failures
2. Facade layer DTO conversions
3. Repository layer queries (via Hibernate)

### Metrics
- Address creation rate
- Validation failure rate
- API response times

---

## Future Enhancements

### Potential Features
1. **Address Verification**: Integrate with address validation service
2. **Geocoding**: Auto-populate latitude/longitude
3. **Address Suggestions**: Auto-complete during entry
4. **Bulk Operations**: Import/export addresses
5. **Address History**: Track address changes
6. **Sharing**: Share addresses between family members

### Technical Improvements
1. **Caching**: Cache frequently accessed addresses
2. **Pagination**: For customers with many addresses
3. **Soft Delete**: Mark as deleted instead of removing
4. **Audit Log**: Track who modified addresses

---

## Troubleshooting

### Common Issues

#### 1. Migration Fails
**Symptom**: Database error on startup
**Solution**: Check existing data in `CUSTOMER` table, ensure `BILLING_FIRST_NAME` and `BILLING_LAST_NAME` are not null

#### 2. Validation Error: "Identical addresses"
**Symptom**: 400 error when adding address
**Solution**: Ensure billing and delivery addresses differ in at least one field (address, city, postalCode, or country)

#### 3. 404 Not Found
**Symptom**: Cannot access address
**Solution**: Verify address belongs to authenticated customer

#### 4. 401 Unauthorized
**Symptom**: Cannot access endpoints
**Solution**: Include valid JWT token in `Authorization: Bearer {token}` header

---

## Testing Checklist

### Manual Testing
- [ ] Create billing address
- [ ] Create delivery address
- [ ] Create multiple addresses of same type
- [ ] Update existing address
- [ ] Delete address
- [ ] Retrieve all addresses
- [ ] Verify ownership validation
- [ ] Verify identical address rejection
- [ ] Test with invalid data
- [ ] Test without authentication

### Automated Testing
- [ ] Run integration tests
- [ ] Run unit tests (when added)
- [ ] Load testing for performance
- [ ] Security testing

---

## Deployment Notes

### Pre-Deployment
1. Backup `CUSTOMER` table
2. Review migration script
3. Test on staging environment

### Deployment Steps
1. Deploy database migration
2. Deploy application code
3. Verify migration success
4. Monitor error logs

### Rollback Plan
1. Revert application code
2. Keep `CUSTOMER_ADDRESS` table (data preserved)
3. Application falls back to embedded addresses

---

## File Summary

### Created Files (13)
1. `AddressType.java` - Enum
2. `CustomerAddress.java` - Entity
3. `CustomerAddressRepository.java` - Repository
4. `CustomerAddressService.java` - Service interface
5. `CustomerAddressServiceImpl.java` - Service implementation
6. `PersistableCustomerAddress.java` - Input DTO
7. `ReadableCustomerAddress.java` - Output DTO
8. `CustomerAddressFacade.java` - Facade interface
9. `CustomerAddressFacadeImpl.java` - Facade implementation
10. `CustomerAddressApi.java` - REST controller
11. `CustomerMultipleAddressesIntegrationTest.java` - Integration test
12. `V1_1__customer_multiple_addresses.sql` - Migration
13. This documentation file

### Modified Files (1)
1. `Customer.java` - Added addresses collection

---

## References

### Related Documentation
- Spring Data JPA: https://spring.io/projects/spring-data-jpa
- Bean Validation: https://beanvalidation.org/
- Spring Security: https://spring.io/projects/spring-security

### Internal Documentation
- Shopizer API Docs: http://localhost:8080/swagger-ui.html
- Database Schema: See migration scripts

---

**Document Version**: 1.0  
**Last Updated**: 2026-02-26  
**Author**: Development Team  
**Status**: Implementation Complete
