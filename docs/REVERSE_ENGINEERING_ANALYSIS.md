# SHOPIZER E-COMMERCE PLATFORM - DEEP REVERSE ENGINEERING ANALYSIS

**Analysis Date**: 2026-02-25  
**Version Analyzed**: 3.2.7  
**Analyst Role**: Senior Software Architect & Reverse Engineering Expert

---

## 1️⃣ SYSTEM OVERVIEW

### Problem Domain
Shopizer solves the **multi-tenant B2C/B2B e-commerce platform** problem, specifically:
- **Multi-store management**: Single deployment serving multiple independent online stores
- **Headless commerce**: Decoupled backend API for omnichannel experiences (web, mobile, IoT)
- **Internationalization**: Multi-language, multi-currency support
- **Complex product catalog**: Variations, attributes, relationships, inventory management
- **Order lifecycle management**: Cart → Checkout → Payment → Fulfillment → Post-sales
- **Extensible integrations**: Payment gateways, shipping providers, cloud storage, email services

### User Personas

| Persona | Role | Primary Goals |
|---------|------|---------------|
| **Store Owner** | Business administrator | Configure store, manage catalog, view orders, configure payments/shipping |
| **Store Manager** | Operations | Process orders, manage inventory, handle customer service |
| **Customer** | End buyer | Browse products, add to cart, checkout, track orders, write reviews |
| **Anonymous Shopper** | Guest buyer | Browse, purchase without registration |
| **Developer** | System integrator | Integrate frontend, customize business logic, extend modules |
| **System Admin** | Platform operator | Manage multiple stores, system configuration, monitoring |

### Core Business Capabilities

1. **Catalog Management**
   - Product CRUD with variants, attributes, options
   - Category hierarchy (tree structure)
   - Manufacturer/brand management
   - Product relationships (related, upsell, cross-sell)
   - Digital product support
   - Product reviews and ratings
   - Inventory tracking per region

2. **Shopping Experience**
   - Persistent shopping cart (guest and registered)
   - Real-time price calculation (base + tax + shipping)
   - Product search with Elasticsearch
   - Multi-currency pricing
   - Promotional pricing

3. **Order Management**
   - Order creation and processing
   - Order status workflow
   - Order history tracking
   - Payment processing (multiple gateways)
   - Shipping calculation and tracking
   - Invoice generation

4. **Customer Management**
   - Registration and authentication (JWT)
   - Profile management
   - Address book (billing/shipping)
   - Order history
   - Customer groups and permissions
   - Social login support (provider field)

5. **Multi-Tenancy**
   - Store isolation (data and configuration)
   - Store hierarchy (parent-child relationships)
   - Per-store branding, currency, language
   - Store-specific catalog and customers

6. **Content Management**
   - Static content pages
   - Image management (product, content)
   - Multiple storage backends (local, S3, GCS)

7. **Business Rules**
   - Tax calculation (Drools-based)
   - Shipping rules
   - Pricing rules
   - Order total calculations

### System Type Classification

**Primary**: **Transactional CRUD Application** with workflow orchestration  
**Secondary Characteristics**:
- **API Gateway** (headless architecture)
- **Integration Hub** (payment, shipping, storage, email)
- **Multi-tenant SaaS** platform
- **Event-driven** (order processing, inventory updates)

**NOT**:
- Pure microservices (monolithic with modular design)
- Batch processor (real-time transactional)
- Workflow engine (embedded workflows, not standalone)

---

## 2️⃣ BUSINESS DOMAIN MODEL

### Core Domain Entities

#### Aggregate Roots (Strong Identity)

1. **MerchantStore** (Tenant Root)
   - ID: Integer
   - Code: String (unique, alphanumeric, e.g., "DEFAULT")
   - Hierarchy: Self-referencing (parent-child)
   - Attributes: Name, address, currency, language, timezone, branding
   - **Invariant**: Code must be unique across all stores
   - **Invariant**: Default language and currency required
   - **Business Rule**: Store can have child stores (marketplace model)

2. **Product**
   - ID: Long
   - SKU: String (unique per store)
   - Lifecycle: Available date, creation date, sort order
   - Composition: Descriptions (i18n), Images, Prices, Attributes, Availability
   - **Invariant**: Must belong to exactly one MerchantStore
   - **Invariant**: Must have at least one ProductAvailability
   - **Business Rule**: Product can have variants (size, color) via ProductVariant
   - **Business Rule**: Product can have relationships (related, upsell)

3. **Category**
   - ID: Long
   - Hierarchy: Self-referencing tree structure
   - Attributes: Code, sort order, visible flag
   - **Invariant**: Must belong to MerchantStore
   - **Business Rule**: Categories form a tree (not DAG)
   - **Ambiguity**: Max depth not enforced in code

4. **Customer**
   - ID: Long
   - Identity: Email (unique per store), Nick (username, unique per store)
   - Authentication: Password (BCrypt), Provider (social login)
   - Attributes: Billing, Delivery, Groups, Reviews
   - **Invariant**: Email required and unique per store
   - **Invariant**: Must belong to MerchantStore
   - **Business Rule**: Can be anonymous (guest checkout)
   - **Business Rule**: Customer can belong to multiple Groups (RBAC)

5. **Order**
   - ID: Long
   - Lifecycle: Status (ORDERED, PROCESSED, DELIVERED, REFUNDED, CANCELLED)
   - Composition: OrderProducts, OrderTotals, OrderStatusHistory, Billing, Delivery
   - References: CustomerId (soft reference, can be detached)
   - **Invariant**: Must have at least one OrderProduct
   - **Invariant**: Total must match sum of OrderTotals
   - **Business Rule**: Order is immutable after creation (only status changes)
   - **Critical**: Customer can be deleted, order persists (customerId + email stored)

6. **ShoppingCart**
   - ID: Long
   - Identity: Code (UUID-like string for guest carts)
   - Composition: ShoppingCartItems
   - **Invariant**: Must belong to MerchantStore
   - **Business Rule**: Cart can exist without customer (anonymous)
   - **Business Rule**: Cart converted to Order on checkout

7. **User** (Admin/Staff)
   - ID: Long
   - Identity: Email (unique per store)
   - Authentication: Password (BCrypt)
   - Authorization: Groups → Permissions
   - **Invariant**: Must belong to MerchantStore
   - **Business Rule**: Separate from Customer entity

#### Value Objects

- **Billing**: Address, name, phone (embedded in Customer/Order)
- **Delivery**: Address, name, phone (embedded in Customer/Order)
- **ProductPrice**: Amount, currency, special price, dates
- **ProductAvailability**: Quantity, region, status
- **OrderTotal**: Type (SUBTOTAL, TAX, SHIPPING, TOTAL), value, sort order
- **AuditSection**: Created date, modified date, created by, modified by

#### Enumerations (Domain Concepts)

- **OrderStatus**: ORDERED, PROCESSED, DELIVERED, REFUNDED, CANCELLED
- **OrderType**: ORDER, QUOTE
- **OrderChannel**: ONLINE, PHONE, MAIL
- **PaymentType**: CREDITCARD, PAYPAL, STRIPE, BRAINTREE, MONEYORDER, COD
- **ProductCondition**: NEW, REFURBISHED, USED
- **CustomerGender**: M, F
- **MeasureUnit**: LB, KG, IN, CM

### Entity Relationship Map

```
MerchantStore (1) ──────────────┐
    │                            │
    │ (1:N)                      │ (1:N)
    ├─ Product                   ├─ Customer
    │    ├─ (1:N) ProductDescription (i18n)
    │    ├─ (1:N) ProductImage
    │    ├─ (1:N) ProductAvailability
    │    │    └─ (1:N) ProductPrice
    │    ├─ (1:N) ProductAttribute (options)
    │    ├─ (N:M) Category
    │    ├─ (N:1) Manufacturer
    │    ├─ (N:1) TaxClass
    │    └─ (1:N) ProductVariant
    │
    ├─ Category (tree)
    │    ├─ (1:N) CategoryDescription (i18n)
    │    └─ (N:1) parent Category
    │
    ├─ Order
    │    ├─ (N:1) Customer (soft reference via customerId)
    │    ├─ (1:N) OrderProduct
    │    │    ├─ (1:N) OrderProductAttribute
    │    │    └─ (1:N) OrderProductPrice
    │    ├─ (1:N) OrderTotal
    │    ├─ (1:N) OrderStatusHistory
    │    ├─ (1:N) OrderAttribute
    │    ├─ (1:1) Billing (embedded)
    │    └─ (1:1) Delivery (embedded)
    │
    ├─ ShoppingCart
    │    └─ (1:N) ShoppingCartItem
    │         ├─ (N:1) Product (reference)
    │         └─ (1:N) ShoppingCartAttributeItem
    │
    ├─ User (admin)
    │    └─ (N:M) Group
    │         └─ (N:M) Permission
    │
    ├─ Manufacturer
    ├─ TaxClass
    ├─ TaxRate
    └─ ShippingOrigin

Reference Data (Shared):
    ├─ Country (1:N) Zone
    ├─ Language
    └─ Currency
```

### Business Rules Summary

#### Product Domain
1. **Product Availability**: Product must have at least one ProductAvailability to be purchasable
2. **Product Pricing**: Price calculated from ProductPrice + TaxClass + Customer location
3. **Product Variants**: Variants share base product but have independent SKU, price, inventory
4. **Product Visibility**: Product.visible flag controls catalog display
5. **Inventory Deduction**: Happens during order processing (not cart addition)

#### Order Domain
1. **Order Immutability**: Once created, order data (products, prices) cannot be modified
2. **Order Status Workflow**: ORDERED → PROCESSED → DELIVERED (or CANCELLED/REFUNDED)
3. **Order Total Calculation**: Subtotal + Tax + Shipping + Discounts = Total
4. **Payment Before Persistence**: Payment processed before order saved to database
5. **Customer Detachment**: Order stores customerId + email; customer can be deleted independently

#### Cart Domain
1. **Cart Persistence**: Carts persisted to database (not session-only)
2. **Cart Expiration**: No automatic expiration logic found (potential issue)
3. **Cart Conversion**: Cart deleted after successful order creation
4. **Anonymous Carts**: Identified by unique code, can be converted to customer cart on login

#### Multi-Tenancy
1. **Store Isolation**: All entities scoped to MerchantStore (except reference data)
2. **Store Hierarchy**: Child stores can inherit configuration from parent
3. **Cross-Store Operations**: Not allowed (enforced at service layer)

#### Pricing & Tax
1. **Multi-Currency**: Prices stored per currency, exchange rate captured at order time
2. **Tax Calculation**: Drools-based rules engine, considers customer location + product tax class
3. **Special Pricing**: Time-bound special prices override base price

### Invariants (Critical Constraints)

1. **MerchantStore.code**: Unique, alphanumeric, not null
2. **Customer.emailAddress**: Unique per store, not null
3. **Product.merchantStore**: Not null (every product belongs to one store)
4. **Order.total**: Must equal sum of OrderTotal entries
5. **Order.customerId**: Can be null if customer deleted (soft reference)
6. **ShoppingCart.merchantStore**: Not null
7. **ProductAvailability.quantity**: Cannot go negative (should be enforced, unclear if it is)

### Implicit Assumptions (Discovered)

1. **Single Currency Per Order**: Order uses one currency (no mixed currency carts)
2. **Region Handling**: ProductAvailability has region field, but logic incomplete (many TODOs)
3. **Inventory Reservation**: No explicit reservation mechanism during checkout (race condition risk)
4. **Cart Abandonment**: No cleanup job for old carts (memory leak potential)
5. **Customer Deletion**: Soft delete assumed but not enforced (orders retain customerId)
6. **Concurrent Order Processing**: No optimistic locking on inventory (potential overselling)

### Unclear/Ambiguous Domain Behavior

1. **Order Modification**: Can order be modified after ORDERED status? Code suggests no, but no explicit validation
2. **Partial Refunds**: OrderStatus has REFUNDED, but no partial refund support visible
3. **Product Variants vs Attributes**: Overlap in functionality, unclear when to use which
4. **Store Hierarchy Depth**: No limit enforced, potential for deep nesting issues
5. **Customer Groups**: Purpose unclear (RBAC? Pricing tiers? Marketing segments?)
6. **Anonymous Customer Lifecycle**: When/how are anonymous customers cleaned up?
7. **Shopping Cart Merge**: What happens when anonymous cart merged with customer cart on login?
8. **Inventory Regions**: Region-based inventory exists but incomplete implementation (TODOs)

---

## 3️⃣ TECHNICAL ARCHITECTURE

### High-Level Architecture Style

**Primary Pattern**: **Layered Monolith** with **Hexagonal Architecture** influences  
**Deployment Model**: Single JAR (Spring Boot fat JAR)  
**Communication**: Synchronous REST API (no async messaging)

### Architecture Characteristics

✅ **Strengths**:
- Clear layer separation (API → Facade → Service → Repository → Entity)
- Dependency inversion for external integrations (payment, shipping, storage)
- Multi-module Maven structure enforces boundaries
- Headless design enables frontend flexibility

❌ **Weaknesses**:
- Tight coupling between layers (service layer knows about JPA entities)
- No domain events (order processing is procedural)
- Anemic domain model (entities are data bags, logic in services)
- Monolithic deployment (cannot scale components independently)

### Module/Package Breakdown

#### 1. **sm-core-model** (Domain Layer)
**Responsibility**: JPA entity definitions, domain enums, value objects  
**Dependencies**: None (pure domain)  
**Key Packages**:
- `com.salesmanager.core.model.catalog` - Product, Category, Manufacturer
- `com.salesmanager.core.model.order` - Order, OrderProduct, OrderTotal
- `com.salesmanager.core.model.customer` - Customer, CustomerAttribute
- `com.salesmanager.core.model.merchant` - MerchantStore
- `com.salesmanager.core.model.shoppingcart` - ShoppingCart, ShoppingCartItem
- `com.salesmanager.core.model.user` - User, Group, Permission
- `com.salesmanager.core.model.reference` - Country, Zone, Language, Currency

**Design Issues**:
- **Anemic Domain Model**: Entities have getters/setters, no behavior
- **JPA Leakage**: Hibernate annotations pollute domain model
- **Bidirectional Relationships**: Many @OneToMany/@ManyToOne pairs (lazy loading issues)

#### 2. **sm-core-modules** (Integration Layer)
**Responsibility**: External system integrations (payment, shipping, email, CMS)  
**Dependencies**: sm-core-model  
**Key Packages**:
- `com.salesmanager.core.modules.integration.payment` - PayPal, Stripe, Braintree
- `com.salesmanager.core.modules.integration.shipping` - USPS, UPS, Canada Post
- `com.salesmanager.core.modules.email` - SMTP, AWS SES
- `com.salesmanager.core.modules.cms` - S3, GCS, local file storage
- `com.salesmanager.core.modules.order.total` - Tax, shipping, discount calculators

**Design Pattern**: **Strategy Pattern** (modules selected at runtime via configuration)

**Design Issues**:
- **Incomplete Implementations**: Many methods have `// TODO Auto-generated method stub`
- **No Circuit Breakers**: External calls can hang indefinitely
- **No Retry Logic**: Transient failures not handled

#### 3. **sm-core** (Business Logic Layer)
**Responsibility**: Business services, repositories, transaction management  
**Dependencies**: sm-core-model, sm-core-modules  
**Key Packages**:
- `com.salesmanager.core.business.services` - Service implementations
- `com.salesmanager.core.business.repositories` - Spring Data JPA repositories
- `com.salesmanager.core.business.configuration` - Spring configuration
- `com.salesmanager.core.business.utils` - Helper utilities

**Service Structure**:
```
SalesManagerEntityService<K, E> (interface)
    ├─ create(E entity)
    ├─ update(E entity)
    ├─ delete(E entity)
    ├─ getById(K id)
    └─ list()

Concrete Services:
    ├─ ProductService
    ├─ OrderService
    ├─ CustomerService
    ├─ ShoppingCartService
    └─ ... (50+ services)
```

**Transaction Management**: `@Transactional` at service layer (Spring declarative)

**Design Issues**:
- **God Services**: OrderService has 680 lines, handles payment, shipping, tax, inventory
- **Service Explosion**: 50+ service classes, many with single method
- **Circular Dependencies**: Services inject each other (e.g., OrderService → CustomerService → OrderService)
- **No Domain Events**: Order processing is procedural, hard to extend

#### 4. **sm-shop-model** (API Contract Layer)
**Responsibility**: REST API DTOs (request/response models)  
**Dependencies**: None (pure DTOs)  
**Key Packages**:
- `com.salesmanager.shop.model.catalog` - Product DTOs
- `com.salesmanager.shop.model.order` - Order DTOs
- `com.salesmanager.shop.model.customer` - Customer DTOs
- `com.salesmanager.shop.model.shoppingcart` - Cart DTOs

**Design Pattern**: **DTO Pattern** (separate API models from domain models)

**Design Issues**:
- **Duplication**: Many DTOs mirror entity structure exactly
- **Versioning**: v0, v1, v2 packages, but no clear migration strategy

#### 5. **sm-shop** (API/Presentation Layer)
**Responsibility**: REST controllers, security, DTO mapping, exception handling  
**Dependencies**: All other modules  
**Key Packages**:
- `com.salesmanager.shop.store.api.v1` - REST API controllers
- `com.salesmanager.shop.store.facade` - Facade layer (orchestration)
- `com.salesmanager.shop.mapper` - MapStruct mappers (DTO ↔ Entity)
- `com.salesmanager.shop.populator` - Legacy populators (DTO ↔ Entity)
- `com.salesmanager.shop.application.config` - Spring Security, Swagger
- `com.salesmanager.shop.store.security` - JWT authentication

**API Structure**:
```
/api/v1/
    ├─ /products/** - Product CRUD, search
    ├─ /category/** - Category management
    ├─ /cart/** - Shopping cart operations
    ├─ /order/** - Order creation, history
    ├─ /customer/** - Customer registration, profile
    ├─ /auth/** - Login, logout, token refresh
    ├─ /payment/** - Payment methods
    ├─ /shipping/** - Shipping options
    └─ /store/** - Store configuration
```

**Security Model**:
- **JWT Authentication**: Stateless tokens (customer and admin separate)
- **Multiple Entry Points**: Customer, Admin, Public, Private APIs
- **Method Security**: `@PreAuthorize` annotations on controllers

**Design Issues**:
- **Facade Duplication**: Facades often just delegate to services (unnecessary layer)
- **Mapper Confusion**: Both MapStruct mappers and legacy populators coexist
- **Exception Handling**: Generic `RestErrorHandler`, loses context

### Dependency Direction

```
sm-shop (API Layer)
    ↓ depends on
sm-shop-model (DTO Layer)
    ↓ depends on
sm-core (Service Layer)
    ↓ depends on
sm-core-modules (Integration Layer)
    ↓ depends on
sm-core-model (Domain Layer)
```

**Violations**:
- sm-shop directly uses sm-core-model entities (should only use DTOs)
- sm-core-model has JPA annotations (should be persistence-agnostic)

### Data Flow (Request Lifecycle)

#### Example: Create Order

```
1. HTTP POST /api/v1/order/DEFAULT
   ↓
2. OrderApi.createOrder(@RequestBody PersistableOrder dto)
   - JWT authentication filter validates token
   - Extract MerchantStore from path ("DEFAULT")
   - Validate request body
   ↓
3. OrderFacade.createOrder(dto, customer, store, language)
   - Map PersistableOrder → Order entity
   - Retrieve ShoppingCart by code
   - Extract ShoppingCartItems
   ↓
4. OrderService.processOrder(order, customer, items, summary, payment, store)
   - Validate inputs (Validate.notNull)
   - Process payment via PaymentService
   ↓
5. PaymentService.processPayment(customer, store, payment, items, order)
   - Select payment module (Stripe/PayPal/etc.)
   - Call external payment API
   - Create Transaction record
   ↓
6. OrderService.processOrder (continued)
   - Calculate tax via TaxService
   - Calculate shipping via ShippingService
   - Calculate order totals via OrderTotalService (Drools rules)
   - Deduct inventory via ProductService
   - Save Order entity (cascade saves OrderProducts, OrderTotals, etc.)
   - Delete ShoppingCart
   - Send confirmation email via EmailService
   ↓
7. OrderFacade.createOrder (continued)
   - Map Order entity → ReadableOrder DTO
   ↓
8. OrderApi.createOrder (continued)
   - Return ResponseEntity<ReadableOrder> (HTTP 200)
```

**Critical Observations**:
- **Long Transaction**: Entire order processing in single transaction (payment + DB save)
- **External Calls in Transaction**: Payment API called inside @Transactional method (risky)
- **No Compensation**: If email fails, order still created (no saga pattern)
- **Synchronous**: All operations blocking (no async processing)

### External Integrations

| Integration | Purpose | Implementation | Configuration |
|-------------|---------|----------------|---------------|
| **MySQL/PostgreSQL/Oracle** | Primary database | Spring Data JPA | `application.properties` |
| **H2** | Default/testing | Embedded | In-memory or file-based |
| **Elasticsearch** | Product search | REST client | `ApplicationSearchConfiguration` |
| **Infinispan** | Distributed cache | Embedded | `infinispan.xml` |
| **EhCache** | Local cache | Spring Cache | `@Cacheable` annotations |
| **PayPal** | Payment gateway | PayPal SDK | Module configuration |
| **Stripe** | Payment gateway | Stripe SDK | Module configuration |
| **Braintree** | Payment gateway | Braintree SDK | Module configuration |
| **AWS S3** | File storage | AWS SDK | Module configuration |
| **Google Cloud Storage** | File storage | GCS SDK | Module configuration |
| **AWS SES** | Email | AWS SDK | Module configuration |
| **SMTP** | Email | JavaMail | Module configuration |
| **Drools** | Business rules | Drools engine | Rule files in classpath |

**Integration Risks**:
- **No Timeouts**: External calls can hang indefinitely
- **No Fallbacks**: If Elasticsearch down, search fails (no degraded mode)
- **No Health Checks**: Actuator endpoints exist but not used for circuit breaking

### Cross-Cutting Concerns

#### 1. Authentication & Authorization
- **JWT Tokens**: Signed with secret key, expiration configurable
- **Token Storage**: Client-side (no server-side session)
- **Token Refresh**: Separate endpoint `/api/v1/auth/refresh`
- **RBAC**: User → Group → Permission (database-driven)
- **Store Isolation**: Token includes store code, validated on each request

**Security Issues**:
- **JWT Secret**: Stored in `application.properties` (should be externalized)
- **No Token Revocation**: Tokens valid until expiration (no blacklist)
- **Password Reset**: Uses embedded token in Customer entity (not separate table)

#### 2. Logging
- **Framework**: SLF4J + Logback
- **Levels**: Configurable per package in `application.properties`
- **Structured Logging**: No (plain text logs)
- **Correlation IDs**: Not implemented (hard to trace requests)

#### 3. Caching
- **Strategy**: Cache-aside (application manages cache)
- **Layers**: 
  - L1: EhCache (local, per-instance)
  - L2: Infinispan (distributed, cluster-aware)
- **Cached Entities**: Products, Categories, Reference data
- **Invalidation**: Manual via `@CacheEvict` on update/delete

**Caching Issues**:
- **Cache Stampede**: No locking on cache miss (thundering herd)
- **Stale Data**: No TTL on some caches (infinite)
- **Inconsistency**: Distributed cache can be out of sync with DB

#### 4. Transactions
- **Boundary**: Service layer (`@Transactional`)
- **Propagation**: REQUIRED (default)
- **Isolation**: READ_COMMITTED (default)
- **Rollback**: On RuntimeException (not checked exceptions)

**Transaction Issues**:
- **Long Transactions**: Order processing includes external API calls
- **N+1 Queries**: Lazy loading in loops (e.g., loading order products)
- **No Optimistic Locking**: Concurrent updates can overwrite each other

#### 5. Validation
- **Bean Validation**: JSR-303 annotations on entities and DTOs
- **Custom Validation**: In service layer (e.g., `Validate.notNull()`)
- **XSS Protection**: OWASP AntiSamy for HTML input

**Validation Issues**:
- **Inconsistent**: Some validation in controllers, some in services
- **Error Messages**: Generic, not user-friendly

#### 6. Error Handling
- **Global Handler**: `RestErrorHandler` with `@ControllerAdvice`
- **Exception Hierarchy**: Custom exceptions (ServiceException, ResourceNotFoundException)
- **HTTP Status Mapping**: 400 (validation), 404 (not found), 500 (server error)

**Error Handling Issues**:
- **Information Leakage**: Stack traces in responses (production risk)
- **No Error Codes**: Hard to programmatically handle errors
- **Lost Context**: Generic exceptions lose business context

---

## 4️⃣ CODE QUALITY & DESIGN ANALYSIS

### Coupling & Cohesion Issues

#### High Coupling Problems

1. **Service Layer Circular Dependencies**
   ```
   OrderService → CustomerService → OrderService (circular)
   OrderService → ProductService → OrderService (circular)
   ShoppingCartService → ProductService → ShoppingCartService (circular)
   ```
   **Impact**: Hard to test, refactor, or extract to microservices

2. **Entity-Service Coupling**
   - Services directly manipulate JPA entities
   - Controllers receive entities from services, convert to DTOs
   - **Example**: `OrderService.processOrder()` returns `Order` entity, not DTO
   - **Impact**: API layer coupled to persistence layer

3. **Module-to-Module Coupling**
   - `sm-shop` depends on ALL other modules
   - Cannot deploy API layer independently
   - **Impact**: Monolithic deployment, slow build times

4. **External Integration Coupling**
   - Payment processing inside order transaction
   - Email sending inside order transaction
   - **Impact**: External failures rollback entire order

#### Low Cohesion Problems

1. **God Services**
   - `OrderServiceImpl`: 680 lines, handles payment, shipping, tax, inventory, email
   - `ProductServiceImpl`: 415 lines, handles CRUD, search, inventory, images
   - **Impact**: Hard to understand, test, maintain

2. **Utility Classes**
   - `ProductPriceUtils`: 21,398 bytes, 500+ lines
   - `EmailTemplatesUtils`: Mixed concerns (template rendering + email sending)
   - **Impact**: Dumping ground for unrelated functions

3. **Facade Layer Redundancy**
   - Many facades just delegate to services without adding value
   - **Example**: `ShoppingCartFacade.addItem()` → `ShoppingCartService.addItem()`
   - **Impact**: Extra layer of indirection, no clear benefit

### SOLID Violations

#### Single Responsibility Principle (SRP) ❌

**Violations**:
1. **OrderService**: Handles order CRUD, payment, shipping, tax, inventory, email
2. **ProductService**: Handles product CRUD, search indexing, inventory, images
3. **MerchantStore Entity**: Business logic + JPA annotations + audit fields

**Example**:
```java
@Service("orderService")
public class OrderServiceImpl {
    @Inject private PaymentService paymentService;
    @Inject private ShippingService shippingService;
    @Inject private TaxService taxService;
    @Inject private ProductService productService;
    @Inject private CustomerService customerService;
    @Inject private ShoppingCartService shoppingCartService;
    @Inject private TransactionService transactionService;
    @Inject private OrderTotalService orderTotalService;
    // ... 680 lines of mixed concerns
}
```

#### Open/Closed Principle (OCP) ⚠️

**Partial Compliance**:
- ✅ Payment modules extensible via strategy pattern
- ✅ Shipping modules extensible via strategy pattern
- ❌ Order processing workflow not extensible (hardcoded steps)
- ❌ Tax calculation uses Drools (good) but no extension points for custom logic

#### Liskov Substitution Principle (LSP) ✅

**Generally Compliant**:
- Service interfaces properly abstracted
- Module interfaces substitutable
- No obvious LSP violations found

#### Interface Segregation Principle (ISP) ⚠️

**Mixed**:
- ✅ Module interfaces focused (PaymentModule, ShippingModule)
- ❌ `SalesManagerEntityService<K, E>` too broad (CRUD + list + count + search)
- ❌ Clients forced to depend on methods they don't use

#### Dependency Inversion Principle (DIP) ⚠️

**Partial Compliance**:
- ✅ Services depend on interfaces (Spring injection)
- ✅ Modules abstracted behind interfaces
- ❌ Services depend on concrete JPA entities (not domain interfaces)
- ❌ No domain layer abstraction (entities ARE the domain)

### God Classes

1. **OrderServiceImpl** (680 lines)
   - Responsibilities: Order CRUD, payment, shipping, tax, inventory, email, invoice
   - Dependencies: 8+ injected services
   - **Refactoring**: Extract OrderProcessor, PaymentProcessor, InventoryManager

2. **ProductServiceImpl** (415 lines)
   - Responsibilities: Product CRUD, search indexing, inventory, images, relationships
   - **Refactoring**: Extract ProductSearchService, ProductInventoryService

3. **ShoppingCartFacadeImpl** (1164 lines)
   - Responsibilities: Cart CRUD, item management, price calculation, DTO mapping
   - **Refactoring**: Extract CartItemManager, CartPriceCalculator

4. **ProductPriceUtils** (500+ lines)
   - Static utility class with complex pricing logic
   - **Refactoring**: Convert to PricingService with strategy pattern

### Anemic Domain Model

**Evidence**:
```java
@Entity
public class Order extends SalesManagerEntity<Long, Order> {
    private OrderStatus status;
    private BigDecimal total;
    private Set<OrderProduct> orderProducts;
    
    // 50+ getters/setters, NO business logic
    public OrderStatus getStatus() { return status; }
    public void setStatus(OrderStatus status) { this.status = status; }
    // ...
}
```

**Problems**:
- Entities are data bags (no behavior)
- Business logic scattered in services
- Invariants not enforced (e.g., order total consistency)
- Domain knowledge not captured in domain layer

**Rich Domain Alternative**:
```java
public class Order {
    public void addProduct(Product product, int quantity) {
        // Validate business rules
        // Update total
        // Emit domain event
    }
    
    public void process(Payment payment) {
        // Validate state transition
        // Process payment
        // Update status
    }
}
```

### Testability Concerns

1. **Service Layer Testing**
   - **Issue**: Services have 8+ dependencies (hard to mock)
   - **Example**: Testing `OrderService` requires mocking PaymentService, ShippingService, TaxService, etc.
   - **Impact**: Tests are brittle, slow, hard to maintain

2. **Integration Testing**
   - **Issue**: No clear boundaries for integration tests
   - **Example**: Testing order creation requires full Spring context + database + Elasticsearch
   - **Impact**: Slow test suite, flaky tests

3. **External Dependencies**
   - **Issue**: Payment/shipping modules call real APIs (no test doubles)
   - **Example**: `PayPalRestPayment` calls PayPal API directly
   - **Impact**: Tests require API keys, network access, or extensive mocking

4. **Static Utilities**
   - **Issue**: Static methods hard to mock
   - **Example**: `ProductPriceUtils.calculatePrice()` cannot be stubbed
   - **Impact**: Tests must use real implementation

5. **Database Coupling**
   - **Issue**: Services depend on JPA repositories (not in-memory alternatives)
   - **Impact**: Tests require database (H2 or Testcontainers)

### Hidden Side Effects

1. **Order Processing Side Effects**
   ```java
   public Order processOrder(...) {
       // Hidden side effects:
       paymentService.processPayment(...);  // External API call
       productService.updateInventory(...);  // Database update
       shoppingCartService.delete(...);      // Database delete
       emailService.sendConfirmation(...);   // External API call
       // No indication in method signature
   }
   ```
   **Impact**: Caller unaware of side effects, hard to reason about

2. **Cascade Operations**
   - JPA cascade settings cause implicit deletes/updates
   - **Example**: Deleting `MerchantStore` cascades to all products, orders, customers
   - **Impact**: Accidental data loss risk

3. **Cache Invalidation**
   - `@CacheEvict` annotations cause hidden cache clears
   - **Impact**: Performance unpredictability

4. **Audit Trail**
   - `AuditSection` automatically populated via JPA listeners
   - **Impact**: Magic behavior, hard to test

### Concurrency & Transaction Risks

#### Critical Race Conditions

1. **Inventory Overselling**
   ```java
   // Thread 1: Check inventory
   if (availability.getQuantity() >= requestedQty) {
       // Thread 2: Check inventory (same product)
       // Both threads see sufficient inventory
       
       // Thread 1: Deduct inventory
       availability.setQuantity(availability.getQuantity() - requestedQty);
       
       // Thread 2: Deduct inventory (OVERSOLD!)
       availability.setQuantity(availability.getQuantity() - requestedQty);
   }
   ```
   **Fix**: Use optimistic locking (`@Version`) or pessimistic locking

2. **Shopping Cart Conflicts**
   - Multiple requests updating same cart concurrently
   - No optimistic locking on `ShoppingCart` entity
   - **Impact**: Lost updates (last write wins)

3. **Order Status Updates**
   - Order status updated from multiple sources (admin, webhook, cron job)
   - No state machine validation
   - **Impact**: Invalid state transitions (e.g., DELIVERED → ORDERED)

#### Transaction Boundary Issues

1. **Long Transactions**
   ```java
   @Transactional
   public Order processOrder(...) {
       // Payment API call (can take 5-10 seconds)
       Transaction tx = paymentService.processPayment(...);
       
       // Database operations
       order.setStatus(OrderStatus.PROCESSED);
       orderRepository.save(order);
       
       // Email API call (can take 2-3 seconds)
       emailService.sendConfirmation(...);
   }
   ```
   **Problems**:
   - Database connection held for 10+ seconds
   - External failures rollback entire transaction
   - Connection pool exhaustion under load

2. **Nested Transactions**
   - Services call other services, both with `@Transactional`
   - Default propagation (REQUIRED) causes nested transactions
   - **Impact**: Unclear transaction boundaries, rollback confusion

3. **LazyInitializationException**
   - Entities with lazy-loaded collections accessed outside transaction
   - **Example**: `order.getOrderProducts()` in controller after service returns
   - **Workaround**: `@Transactional(readOnly = true)` on controllers (bad practice)

#### Deadlock Risks

1. **Order Processing**
   - Locks: Customer → Product → Order
   - Concurrent orders for same customer + product can deadlock
   - **Mitigation**: None found in code

2. **Category Tree Updates**
   - Self-referencing `Category` table
   - Updating parent-child relationships can deadlock
   - **Mitigation**: None found in code

---

## 5️⃣ DATA & STATE MANAGEMENT

### Data Ownership Model

#### Aggregate Boundaries

**Properly Defined**:
1. **Order Aggregate**
   - Root: `Order`
   - Children: `OrderProduct`, `OrderTotal`, `OrderStatusHistory`, `OrderAttribute`
   - Lifecycle: Children cannot exist without Order
   - Access: Always through Order root

2. **Product Aggregate**
   - Root: `Product`
   - Children: `ProductDescription`, `ProductImage`, `ProductAvailability`, `ProductPrice`
   - Lifecycle: Tightly coupled to Product

**Poorly Defined**:
1. **Customer Aggregate**
   - Root: `Customer`
   - Children: `CustomerAttribute`, `ProductReview`
   - **Issue**: `ProductReview` also references `Product` (cross-aggregate reference)
   - **Impact**: Unclear ownership, potential consistency issues

2. **ShoppingCart Aggregate**
   - Root: `ShoppingCart`
   - Children: `ShoppingCartItem`
   - **Issue**: `ShoppingCartItem` references `Product` directly (not by ID)
   - **Impact**: Lazy loading issues, transaction boundary confusion

#### Cross-Aggregate References

**By ID (Good)**:
- `Order.customerId` (Long) - Customer can be deleted independently
- `OrderProduct.productId` (implicit via JPA) - Product can be modified after order

**By Entity (Problematic)**:
- `ShoppingCartItem.product` (Product entity) - Causes lazy loading issues
- `ProductReview.customer` (Customer entity) - Tight coupling
- `ProductReview.product` (Product entity) - Tight coupling

**Recommendation**: Use IDs for cross-aggregate references, load entities explicitly when needed

### Transaction Boundaries

#### Current Boundaries (Service Layer)

```java
@Service
public class OrderServiceImpl {
    
    @Transactional  // Transaction starts here
    public Order processOrder(Order order, Customer customer, ...) {
        // 1. Process payment (external API call)
        Transaction tx = paymentService.processPayment(...);
        
        // 2. Calculate tax (Drools rules)
        List<OrderTotal> totals = taxService.calculateTax(...);
        
        // 3. Update inventory (database update)
        productService.updateInventory(...);
        
        // 4. Save order (database insert)
        Order saved = orderRepository.save(order);
        
        // 5. Delete cart (database delete)
        shoppingCartService.delete(cart);
        
        // 6. Send email (external API call)
        emailService.sendConfirmation(...);
        
        return saved;
    }  // Transaction commits here (or rolls back on exception)
}
```

**Problems**:
1. **Too Coarse**: Single transaction spans multiple business operations
2. **External Calls**: Payment and email inside transaction (risky)
3. **Long Duration**: Can hold DB connection for 10+ seconds
4. **All-or-Nothing**: Email failure rolls back entire order

#### Recommended Boundaries

**Option 1: Saga Pattern**
```
1. Process payment (separate transaction)
2. Create order (separate transaction)
3. Update inventory (separate transaction)
4. Send email (async, no transaction)

Compensation:
- If step 3 fails → refund payment, cancel order
- If step 4 fails → retry async, don't rollback
```

**Option 2: Event-Driven**
```
1. Create order (transaction)
2. Publish OrderCreated event
3. Event handlers:
   - InventoryHandler: Update inventory
   - EmailHandler: Send confirmation
   - AnalyticsHandler: Track conversion
```

### Consistency Model

#### Strong Consistency (ACID)

**Enforced**:
- Order creation (all OrderProducts, OrderTotals saved atomically)
- Product updates (Product + ProductAvailability + ProductPrice)
- Customer registration (Customer + Billing + Delivery)

**Not Enforced**:
- Inventory deduction (no optimistic locking, race conditions possible)
- Order status transitions (no state machine validation)
- Shopping cart updates (no conflict resolution)

#### Eventual Consistency

**Implemented**:
- Elasticsearch indexing (async, can lag behind database)
- Cache updates (manual invalidation, can be stale)

**Not Implemented**:
- Cross-aggregate consistency (e.g., Customer deletion doesn't update Orders)
- Distributed transactions (no 2PC or saga pattern)

#### Consistency Issues Found

1. **Order Total Mismatch**
   - `Order.total` field vs. sum of `OrderTotal` entries
   - No validation to ensure they match
   - **Risk**: Data corruption if manually updated

2. **Inventory Inconsistency**
   - `ProductAvailability.quantity` can go negative (no constraint)
   - Concurrent updates can cause overselling
   - **Risk**: Selling products that are out of stock

3. **Customer-Order Relationship**
   - `Order.customerId` is soft reference (can be null)
   - Customer can be deleted, orders remain
   - **Risk**: Orphaned orders, reporting issues

4. **Shopping Cart Expiration**
   - No cleanup job for abandoned carts
   - Carts accumulate indefinitely
   - **Risk**: Database bloat, performance degradation

### Caching Strategy

#### Cache Layers

**L1 Cache (EhCache - Local)**
- Scope: Single application instance
- Entities: Products, Categories, Reference data
- TTL: Configurable (default: infinite)
- Eviction: LRU (Least Recently Used)

**L2 Cache (Infinispan - Distributed)**
- Scope: Cluster-wide
- Entities: Products, Categories, MerchantStore
- TTL: Configurable (default: infinite)
- Eviction: Manual via `@CacheEvict`

#### Cache Invalidation

**Manual Invalidation**:
```java
@CacheEvict(value = "products", key = "#product.id")
public void updateProduct(Product product) {
    productRepository.save(product);
}
```

**Problems**:
1. **Inconsistent**: Some updates invalidate cache, others don't
2. **Partial Invalidation**: Updating product doesn't invalidate category cache
3. **Distributed Inconsistency**: L1 cache can be stale after L2 update
4. **No TTL**: Some caches never expire (infinite stale data risk)

#### Cache Stampede Risk

**Scenario**:
```
1. Cache expires for popular product
2. 1000 concurrent requests hit database
3. All requests load product from DB
4. All requests write to cache (thundering herd)
```

**Mitigation**: None found in code (should use locking or probabilistic early expiration)

#### Recommended Caching Strategy

1. **Read-Through Cache**: Load from DB on cache miss, populate cache automatically
2. **Write-Through Cache**: Update DB and cache atomically
3. **TTL-Based Expiration**: All caches should have TTL (e.g., 5 minutes)
4. **Cache Warming**: Pre-populate cache on startup for hot data
5. **Circuit Breaker**: Fallback to DB if cache unavailable

### Migration Risks

#### Schema Evolution

**Current Approach**:
- Hibernate DDL auto-update (`spring.jpa.hibernate.ddl-auto=update`)
- No explicit migration scripts
- **Risk**: Schema drift between environments, data loss on column drops

**Recommended Approach**:
- Use Flyway or Liquibase for versioned migrations
- Disable Hibernate auto-DDL in production
- Test migrations in staging before production

#### Data Migration Challenges

1. **Multi-Tenancy**
   - Migrating data for 100+ stores
   - Need to maintain store isolation
   - **Risk**: Cross-store data leakage

2. **Order History**
   - Orders reference products by ID (not snapshot)
   - Product changes affect historical orders
   - **Risk**: Order details change retroactively

3. **Customer Data**
   - GDPR compliance (right to be forgotten)
   - Customer deletion affects orders, reviews, carts
   - **Risk**: Referential integrity violations

4. **Elasticsearch Reindexing**
   - Full reindex required after schema changes
   - Can take hours for large catalogs
   - **Risk**: Search downtime during reindex

#### Backward Compatibility

**API Versioning**:
- v0 (deprecated), v1 (current), v2 (new)
- No clear deprecation policy
- **Risk**: Breaking changes without notice

**Database Versioning**:
- No version tracking in database
- **Risk**: Cannot determine schema version at runtime

---

## 6️⃣ RISK ASSESSMENT

### Technical Debt Hotspots

#### 🔴 CRITICAL (Immediate Attention)

1. **Inventory Race Conditions**
   - **Location**: `ProductServiceImpl.updateInventory()`
   - **Issue**: No optimistic locking, concurrent updates cause overselling
   - **Impact**: Revenue loss, customer dissatisfaction
   - **Effort**: Medium (add `@Version` field, update logic)

2. **Long Transactions with External Calls**
   - **Location**: `OrderServiceImpl.processOrder()`
   - **Issue**: Payment/email inside transaction, holds DB connection
   - **Impact**: Connection pool exhaustion, deadlocks, rollback on email failure
   - **Effort**: High (refactor to saga pattern or event-driven)

3. **JWT Secret in Properties File**
   - **Location**: `application.properties`
   - **Issue**: Secret key committed to version control
   - **Impact**: Security breach, token forgery
   - **Effort**: Low (externalize to environment variable or vault)

4. **No Cart Cleanup**
   - **Location**: `ShoppingCartService`
   - **Issue**: Abandoned carts never deleted
   - **Impact**: Database bloat, performance degradation
   - **Effort**: Low (add scheduled job to delete old carts)

#### 🟡 HIGH (Address Soon)

5. **God Services**
   - **Location**: `OrderServiceImpl`, `ProductServiceImpl`, `ShoppingCartFacadeImpl`
   - **Issue**: 400-1100 lines, mixed concerns, hard to test
   - **Impact**: Maintenance burden, slow feature development
   - **Effort**: High (extract smaller services, refactor)

6. **Anemic Domain Model**
   - **Location**: All entities in `sm-core-model`
   - **Issue**: No business logic in domain layer, scattered in services
   - **Impact**: Duplicate logic, invariants not enforced
   - **Effort**: Very High (move logic to entities, refactor services)

7. **Incomplete Module Implementations**
   - **Location**: `sm-core-modules` (100+ TODOs)
   - **Issue**: Many methods are stubs (`// TODO Auto-generated method stub`)
   - **Impact**: Features don't work, runtime errors
   - **Effort**: Medium (implement missing methods)

8. **No Circuit Breakers**
   - **Location**: All external integrations (payment, shipping, email)
   - **Issue**: External failures cascade to application
   - **Impact**: Downtime, poor user experience
   - **Effort**: Medium (add Resilience4j or Hystrix)

#### 🟢 MEDIUM (Plan for Future)

9. **Circular Service Dependencies**
   - **Location**: Service layer
   - **Issue**: Services inject each other, hard to test/refactor
   - **Impact**: Tight coupling, cannot extract to microservices
   - **Effort**: High (refactor to event-driven or domain events)

10. **Cache Inconsistency**
    - **Location**: Caching layer
    - **Issue**: Manual invalidation, no TTL, distributed inconsistency
    - **Impact**: Stale data, incorrect prices/inventory
    - **Effort**: Medium (implement cache-aside pattern with TTL)

11. **No Observability**
    - **Location**: Entire application
    - **Issue**: No correlation IDs, structured logging, distributed tracing
    - **Impact**: Hard to debug production issues
    - **Effort**: Medium (add Sleuth, Zipkin, structured logging)

12. **Hibernate N+1 Queries**
    - **Location**: Lazy-loaded collections (e.g., `Order.orderProducts`)
    - **Issue**: Loading 100 orders triggers 100+ queries
    - **Impact**: Performance degradation, slow API responses
    - **Effort**: Medium (add `@EntityGraph` or DTO projections)

### High-Change Areas

**Based on TODO comments and incomplete implementations**:

1. **Region-Based Inventory** (20+ TODOs)
   - Feature partially implemented, many TODOs
   - **Risk**: Incomplete feature, unclear requirements

2. **Shipping Modules** (15+ TODOs)
   - USPS, UPS, Canada Post have stub methods
   - **Risk**: Shipping calculation failures

3. **Payment Modules** (10+ TODOs)
   - BeanStream, PayPal have incomplete implementations
   - **Risk**: Payment processing failures

4. **Product Pricing** (8+ TODOs)
   - Complex pricing logic with many edge cases
   - **Risk**: Incorrect prices, revenue loss

### Security Risks

#### 🔴 CRITICAL

1. **JWT Secret Exposure**
   - Secret key in `application.properties` (version controlled)
   - **Exploit**: Attacker can forge tokens, impersonate users
   - **Mitigation**: Externalize to environment variable or vault

2. **SQL Injection** (Low Risk)
   - Using JPA/Hibernate (parameterized queries)
   - Custom queries use `@Query` with parameters
   - **Risk**: Low (but audit custom queries)

3. **XSS Protection**
   - OWASP AntiSamy used for HTML input
   - **Risk**: Medium (ensure all user input sanitized)

#### 🟡 HIGH

4. **No Token Revocation**
   - JWT tokens valid until expiration (no blacklist)
   - **Exploit**: Stolen tokens usable until expiration
   - **Mitigation**: Implement token blacklist or short expiration + refresh tokens

5. **Password Reset Vulnerability**
   - Reset token embedded in Customer entity (not separate table)
   - **Risk**: Token reuse, no expiration enforcement

6. **CORS Configuration**
   - Permissive CORS settings (allow all origins in dev)
   - **Risk**: CSRF attacks if not properly configured in production

#### 🟢 MEDIUM

7. **Information Leakage**
   - Stack traces in error responses
   - **Risk**: Exposes internal implementation details

8. **No Rate Limiting**
   - No throttling on API endpoints
   - **Risk**: Brute force attacks, DDoS

### Scalability Bottlenecks

#### Database

1. **Single Database**
   - All stores share one database
   - **Bottleneck**: Database becomes single point of failure
   - **Scaling**: Read replicas, sharding by store

2. **N+1 Queries**
   - Lazy loading in loops
   - **Bottleneck**: 100 orders = 100+ queries
   - **Scaling**: Eager loading, DTO projections

3. **Long Transactions**
   - Order processing holds connection for 10+ seconds
   - **Bottleneck**: Connection pool exhaustion
   - **Scaling**: Shorter transactions, async processing

#### Elasticsearch

4. **Single Elasticsearch Instance**
   - No clustering configured
   - **Bottleneck**: Search downtime if instance fails
   - **Scaling**: Elasticsearch cluster with replicas

5. **Synchronous Indexing**
   - Product updates block on Elasticsearch indexing
   - **Bottleneck**: Slow product updates
   - **Scaling**: Async indexing via message queue

#### Application

6. **Synchronous Order Processing**
   - Order creation blocks on payment, email, inventory
   - **Bottleneck**: Slow checkout, poor user experience
   - **Scaling**: Async processing, event-driven

7. **No Horizontal Scaling**
   - Stateless (good) but no load balancing configuration
   - **Bottleneck**: Single instance handles all traffic
   - **Scaling**: Deploy multiple instances behind load balancer

8. **Cache Stampede**
   - Popular products cause thundering herd on cache miss
   - **Bottleneck**: Database overload
   - **Scaling**: Locking on cache miss, probabilistic expiration

### Refactoring Difficulty Estimation

| Component | Difficulty | Reason | Recommended Approach |
|-----------|-----------|--------|---------------------|
| **Order Processing** | 🔴 **HIGH** | Long transaction, external calls, 8+ dependencies | Saga pattern or event-driven, 3-6 months |
| **Inventory Management** | 🟡 **MEDIUM** | Race conditions, no locking | Add optimistic locking, 2-4 weeks |
| **Service Layer** | 🔴 **HIGH** | Circular dependencies, god services | Extract domain events, 6-12 months |
| **Domain Model** | 🔴 **VERY HIGH** | Anemic model, logic in services | Move logic to entities, 12+ months |
| **Caching** | 🟡 **MEDIUM** | Manual invalidation, no TTL | Implement cache-aside with TTL, 1-2 months |
| **Security** | 🟢 **LOW** | JWT secret, token revocation | Externalize secrets, add blacklist, 1-2 weeks |
| **Observability** | 🟡 **MEDIUM** | No correlation IDs, tracing | Add Sleuth + Zipkin, 1 month |
| **API Versioning** | 🟢 **LOW** | No deprecation policy | Document policy, add deprecation headers, 1 week |

---

## 7️⃣ UNKNOWNS & QUESTIONS

### Assumptions Made During Analysis

1. **Production Configuration**
   - Assumed `application.properties` represents production config
   - **Reality**: May have environment-specific overrides
   - **Validate**: Check deployment scripts, Kubernetes ConfigMaps, or environment variables

2. **Load Characteristics**
   - Assumed moderate traffic (100-1000 req/sec)
   - **Reality**: Unknown actual load patterns
   - **Validate**: Check application logs, APM metrics, or load test results

3. **Data Volume**
   - Assumed moderate catalog size (10K-100K products)
   - **Reality**: Unknown actual data volume
   - **Validate**: Query database for row counts, check Elasticsearch index size

4. **Multi-Tenancy Usage**
   - Assumed 10-100 stores per deployment
   - **Reality**: Could be single-tenant or 1000+ stores
   - **Validate**: Check `MERCHANT_STORE` table row count

5. **Deployment Model**
   - Assumed single-instance deployment
   - **Reality**: May be clustered, containerized, or serverless
   - **Validate**: Check Docker Compose, Kubernetes manifests, or AWS ECS config

6. **External Service SLAs**
   - Assumed payment/shipping APIs have 99% uptime
   - **Reality**: Unknown actual SLAs
   - **Validate**: Check vendor documentation, monitoring dashboards

7. **Business Rules Complexity**
   - Assumed simple tax/shipping rules
   - **Reality**: Drools rules may be complex
   - **Validate**: Review `.drl` files in classpath

8. **Customer Behavior**
   - Assumed 10% cart abandonment rate
   - **Reality**: Unknown actual abandonment rate
   - **Validate**: Analyze `SHOPPING_CART` table for old carts

### Clarifying Questions for Stakeholders

#### Business Domain

1. **Multi-Tenancy Model**
   - Q: How many stores per deployment? (1, 10, 100, 1000+?)
   - Q: Do stores share customers? (marketplace model vs. isolated stores)
   - Q: Can products be shared across stores? (catalog syndication)
   - Q: What is the store hierarchy depth? (parent → child → grandchild?)

2. **Order Lifecycle**
   - Q: Can orders be modified after creation? (add/remove items, change address)
   - Q: What triggers order status transitions? (manual, webhook, cron job)
   - Q: Are partial refunds supported? (code suggests no)
   - Q: What happens if payment succeeds but order save fails? (compensation logic)

3. **Inventory Management**
   - Q: Is inventory tracked per region? (code has TODOs for this)
   - Q: What happens when inventory goes negative? (backorders, cancellation)
   - Q: Is inventory reserved during checkout? (or only deducted on order creation)
   - Q: How are inventory adjustments handled? (manual, automated, sync with warehouse)

4. **Customer Management**
   - Q: Can customers be deleted? (GDPR right to be forgotten)
   - Q: What happens to orders when customer deleted? (anonymize, keep, delete)
   - Q: Are anonymous customers converted to registered? (on login after guest checkout)
   - Q: What is the customer group model? (pricing tiers, permissions, marketing segments)

5. **Product Catalog**
   - Q: What is the difference between ProductVariant and ProductAttribute? (when to use which)
   - Q: Can products belong to multiple categories? (code suggests yes via many-to-many)
   - Q: Are digital products fully supported? (code exists but unclear if complete)
   - Q: How are product relationships used? (related, upsell, cross-sell)

6. **Pricing & Promotions**
   - Q: How are promotions applied? (coupon codes, automatic, customer-specific)
   - Q: Can multiple promotions stack? (e.g., 10% off + free shipping)
   - Q: Are prices negotiable? (B2B use case)
   - Q: How are bulk discounts handled? (quantity-based pricing)

7. **Shopping Cart**
   - Q: How long should carts persist? (days, weeks, forever)
   - Q: What happens to cart when product price changes? (update cart, keep old price)
   - Q: Can carts be shared? (email cart, save for later)
   - Q: How are cart conflicts resolved? (concurrent updates)

#### Technical Architecture

8. **Deployment & Scaling**
   - Q: What is the current deployment model? (single instance, cluster, cloud)
   - Q: What is the expected traffic? (req/sec, concurrent users)
   - Q: What is the expected data volume? (products, orders, customers)
   - Q: What are the SLAs? (uptime, response time, error rate)

9. **External Integrations**
   - Q: Which payment gateways are actively used? (PayPal, Stripe, Braintree, all?)
   - Q: Which shipping providers are actively used? (USPS, UPS, Canada Post, all?)
   - Q: Which storage backend is used? (local, S3, GCS)
   - Q: Which email provider is used? (SMTP, AWS SES)

10. **Data Management**
    - Q: What is the database backup strategy? (frequency, retention, recovery time)
    - Q: What is the database migration strategy? (Flyway, Liquibase, manual)
    - Q: How is Elasticsearch kept in sync? (real-time, batch, manual)
    - Q: What is the cache invalidation strategy? (manual, TTL, event-driven)

11. **Security & Compliance**
    - Q: What are the security requirements? (PCI-DSS, GDPR, SOC 2)
    - Q: How are secrets managed? (environment variables, vault, config files)
    - Q: What is the token expiration policy? (minutes, hours, days)
    - Q: Is audit logging required? (who did what when)

12. **Monitoring & Operations**
    - Q: What monitoring tools are used? (Prometheus, Grafana, Datadog, New Relic)
    - Q: What is the alerting strategy? (on-call, email, Slack)
    - Q: What are the key metrics? (orders/sec, revenue, error rate)
    - Q: How are production issues debugged? (logs, APM, profiling)

### Code Investigation Tasks

#### High Priority

1. **Inventory Locking Mechanism**
   - **File**: `ProductServiceImpl.java`, `ProductAvailabilityServiceImpl.java`
   - **Question**: Is optimistic locking used? (`@Version` field)
   - **Action**: Search for `@Version` annotation in `ProductAvailability` entity

2. **Order Transaction Boundaries**
   - **File**: `OrderServiceImpl.java`
   - **Question**: What is the actual transaction scope? (method-level, class-level)
   - **Action**: Check `@Transactional` annotations, test rollback behavior

3. **Cart Cleanup Job**
   - **File**: Search for `@Scheduled` annotations
   - **Question**: Is there a scheduled job to delete old carts?
   - **Action**: `grep -r "@Scheduled" sm-shop/src/`

4. **JWT Secret Configuration**
   - **File**: `application.properties`, environment-specific configs
   - **Question**: Is JWT secret externalized in production?
   - **Action**: Check deployment scripts, Kubernetes secrets

5. **Payment Compensation Logic**
   - **File**: `OrderServiceImpl.java`, `PaymentServiceImpl.java`
   - **Question**: What happens if order save fails after payment succeeds?
   - **Action**: Trace exception handling, look for refund logic

6. **Elasticsearch Sync Mechanism**
   - **File**: `ProductServiceImpl.java`, `SearchServiceImpl.java`
   - **Question**: Is indexing synchronous or asynchronous?
   - **Action**: Look for `@Async` annotations, message queue integration

7. **Cache TTL Configuration**
   - **File**: `ehcache.xml`, `infinispan.xml`
   - **Question**: What are the actual TTL values?
   - **Action**: Check cache configuration files

8. **Customer Deletion Logic**
   - **File**: `CustomerServiceImpl.java`
   - **Question**: Is customer deletion soft or hard? What happens to orders?
   - **Action**: Check delete method implementation, cascade settings

#### Medium Priority

9. **Store Hierarchy Logic**
   - **File**: `MerchantStoreServiceImpl.java`
   - **Question**: How is store hierarchy used? (inheritance, isolation)
   - **Action**: Search for `parent` field usage, check business logic

10. **Product Variant vs Attribute**
    - **File**: `ProductServiceImpl.java`, `ProductVariantServiceImpl.java`
    - **Question**: When to use variants vs. attributes?
    - **Action**: Check documentation, test data, API examples

11. **Drools Rules**
    - **File**: `*.drl` files in `src/main/resources`
    - **Question**: What business rules are implemented?
    - **Action**: Review Drools rule files, check tax/shipping logic

12. **API Deprecation Policy**
    - **File**: API controllers, Swagger annotations
    - **Question**: How are deprecated APIs marked? What is the sunset timeline?
    - **Action**: Search for `@Deprecated` annotations, check API documentation

### Missing Documentation

1. **Architecture Decision Records (ADRs)**
   - No ADRs found in repository
   - **Impact**: Unclear why certain design decisions were made
   - **Action**: Interview original developers, create ADRs retroactively

2. **API Documentation**
   - Swagger UI exists but no written API guide
   - **Impact**: Hard for developers to integrate
   - **Action**: Create API documentation with examples

3. **Deployment Guide**
   - README has basic Docker commands but no production deployment guide
   - **Impact**: Unclear how to deploy to production
   - **Action**: Document deployment process, infrastructure requirements

4. **Runbook**
   - No operational runbook for common issues
   - **Impact**: Hard to troubleshoot production issues
   - **Action**: Create runbook with common issues and solutions

5. **Data Model Diagram**
   - No ER diagram or data model documentation
   - **Impact**: Hard to understand relationships
   - **Action**: Generate ER diagram from database schema

6. **Business Rules Documentation**
   - Drools rules exist but no explanation of business logic
   - **Impact**: Hard to modify rules without breaking business logic
   - **Action**: Document business rules in plain language

---

## 8️⃣ REFACTORING STRATEGY

### Safe First Steps (Low Risk, High Value)

#### 1. Externalize JWT Secret (1 day)
**Current**:
```properties
# application.properties
jwt.secret=mySecretKey123
```

**Refactored**:
```properties
# application.properties
jwt.secret=${JWT_SECRET}
```
```bash
# Environment variable
export JWT_SECRET=$(openssl rand -base64 32)
```

**Impact**: Eliminates critical security risk  
**Risk**: Low (backward compatible)

#### 2. Add Cart Cleanup Job (2 days)
**Implementation**:
```java
@Component
public class CartCleanupJob {
    @Scheduled(cron = "0 0 2 * * ?")  // 2 AM daily
    public void cleanupAbandonedCarts() {
        LocalDateTime cutoff = LocalDateTime.now().minusDays(30);
        shoppingCartService.deleteOlderThan(cutoff);
    }
}
```

**Impact**: Prevents database bloat  
**Risk**: Low (only deletes old data)

#### 3. Add Optimistic Locking to Inventory (3 days)
**Current**:
```java
@Entity
public class ProductAvailability {
    private Integer quantity;
    // No version field
}
```

**Refactored**:
```java
@Entity
public class ProductAvailability {
    @Version
    private Long version;
    
    private Integer quantity;
}
```

**Impact**: Prevents inventory overselling  
**Risk**: Medium (requires testing, may cause OptimisticLockException)

#### 4. Add Correlation IDs (1 week)
**Implementation**:
```java
@Component
public class CorrelationIdFilter extends OncePerRequestFilter {
    @Override
    protected void doFilterInternal(HttpServletRequest request, 
                                     HttpServletResponse response, 
                                     FilterChain filterChain) {
        String correlationId = UUID.randomUUID().toString();
        MDC.put("correlationId", correlationId);
        response.setHeader("X-Correlation-ID", correlationId);
        filterChain.doFilter(request, response);
        MDC.clear();
    }
}
```

**Impact**: Easier debugging, request tracing  
**Risk**: Low (non-invasive)

#### 5. Add Health Checks (2 days)
**Implementation**:
```java
@Component
public class DatabaseHealthIndicator implements HealthIndicator {
    @Override
    public Health health() {
        try {
            // Check database connection
            return Health.up().build();
        } catch (Exception e) {
            return Health.down(e).build();
        }
    }
}
```

**Impact**: Better monitoring, faster incident response  
**Risk**: Low (read-only checks)

### How to Add Tests Safely

#### Strategy: Characterization Tests

**Goal**: Capture current behavior before refactoring

**Approach**:
1. **Identify Critical Paths**
   - Order creation
   - Payment processing
   - Inventory deduction
   - Cart management

2. **Write Integration Tests**
   ```java
   @SpringBootTest
   @Transactional
   public class OrderProcessingTest {
       @Test
       public void testOrderCreation_withValidData_createsOrder() {
           // Arrange: Create test data
           Customer customer = createTestCustomer();
           Product product = createTestProduct();
           ShoppingCart cart = createTestCart(customer, product);
           
           // Act: Process order
           Order order = orderService.processOrder(...);
           
           // Assert: Verify order created
           assertNotNull(order.getId());
           assertEquals(OrderStatus.PROCESSED, order.getStatus());
           assertEquals(1, order.getOrderProducts().size());
       }
   }
   ```

3. **Use Test Containers**
   ```java
   @Testcontainers
   public class OrderProcessingTest {
       @Container
       static MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.0");
       
       @Container
       static ElasticsearchContainer elasticsearch = 
           new ElasticsearchContainer("elasticsearch:7.5.2");
   }
   ```

4. **Mock External Services**
   ```java
   @MockBean
   private PaymentModule paymentModule;
   
   @Test
   public void testOrderCreation_paymentSuccess() {
       when(paymentModule.processPayment(...))
           .thenReturn(successfulTransaction());
       
       Order order = orderService.processOrder(...);
       
       verify(paymentModule).processPayment(...);
   }
   ```

#### Test Pyramid

```
        /\
       /  \  E2E Tests (5%)
      /____\
     /      \  Integration Tests (25%)
    /________\
   /          \  Unit Tests (70%)
  /__________\
```

**Priority**:
1. **Unit Tests**: Service layer methods (fast, isolated)
2. **Integration Tests**: Database operations, API endpoints (slower, realistic)
3. **E2E Tests**: Critical user journeys (slowest, most realistic)

### Strangler Pattern Approach

**Goal**: Gradually replace legacy code without big-bang rewrite

#### Phase 1: Identify Seams (1 month)
1. **Extract Interfaces**
   ```java
   // Legacy
   public class OrderServiceImpl {
       public Order processOrder(...) { ... }
   }
   
   // Refactored
   public interface OrderProcessor {
       Order processOrder(...);
   }
   
   public class LegacyOrderProcessor implements OrderProcessor {
       // Existing implementation
   }
   ```

2. **Add Feature Flags**
   ```java
   @Service
   public class OrderService {
       @Value("${feature.new-order-processor:false}")
       private boolean useNewProcessor;
       
       public Order processOrder(...) {
           if (useNewProcessor) {
               return newOrderProcessor.processOrder(...);
           } else {
               return legacyOrderProcessor.processOrder(...);
           }
       }
   }
   ```

#### Phase 2: Build New Implementation (3-6 months)
1. **Event-Driven Order Processing**
   ```java
   @Service
   public class EventDrivenOrderProcessor implements OrderProcessor {
       public Order processOrder(...) {
           // 1. Create order (short transaction)
           Order order = orderRepository.save(order);
           
           // 2. Publish event (async)
           eventPublisher.publish(new OrderCreatedEvent(order));
           
           return order;
       }
   }
   
   @EventListener
   public void handleOrderCreated(OrderCreatedEvent event) {
       // Process payment (separate transaction)
       // Update inventory (separate transaction)
       // Send email (async, no transaction)
   }
   ```

2. **Run Both Implementations in Parallel**
   ```java
   public Order processOrder(...) {
       Order legacyResult = legacyOrderProcessor.processOrder(...);
       
       if (useNewProcessor) {
           Order newResult = newOrderProcessor.processOrder(...);
           compareResults(legacyResult, newResult);  // Log differences
       }
       
       return legacyResult;  // Still use legacy result
   }
   ```

#### Phase 3: Gradual Rollout (2-3 months)
1. **Canary Deployment**: 5% traffic → new implementation
2. **Monitor Metrics**: Error rate, latency, business metrics
3. **Increase Traffic**: 10% → 25% → 50% → 100%
4. **Rollback Plan**: Feature flag to revert to legacy

#### Phase 4: Decommission Legacy (1 month)
1. **Remove Feature Flag**
2. **Delete Legacy Code**
3. **Update Documentation**

### Modularization Opportunities

#### Extract Bounded Contexts

**Current Monolith**:
```
shopizer
├─ catalog (products, categories)
├─ order (orders, payments)
├─ customer (customers, auth)
├─ cart (shopping carts)
└─ merchant (stores, config)
```

**Target Microservices** (if needed):
```
catalog-service
├─ Product management
├─ Category management
├─ Search
└─ Inventory

order-service
├─ Order creation
├─ Order status
└─ Order history

payment-service
├─ Payment processing
├─ Transaction management
└─ Refunds

customer-service
├─ Customer registration
├─ Authentication
├─ Profile management
└─ Address book

cart-service
├─ Cart management
├─ Cart items
└─ Price calculation
```

**Communication**:
- **Synchronous**: REST APIs (for queries)
- **Asynchronous**: Message queue (for events)
- **Data**: Each service owns its database

**Migration Path**:
1. **Extract Cart Service** (least dependencies)
2. **Extract Customer Service** (authentication boundary)
3. **Extract Catalog Service** (read-heavy, can be scaled independently)
4. **Extract Order Service** (most complex, do last)

### Observability Improvements

#### 1. Distributed Tracing (1 week)
**Add Spring Cloud Sleuth + Zipkin**:
```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-sleuth</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-sleuth-zipkin</artifactId>
</dependency>
```

**Result**: Trace requests across services, identify bottlenecks

#### 2. Structured Logging (3 days)
**Add Logstash Encoder**:
```xml
<dependency>
    <groupId>net.logstash.logback</groupId>
    <artifactId>logstash-logback-encoder</artifactId>
</dependency>
```

**Configuration**:
```xml
<appender name="JSON" class="ch.qos.logback.core.ConsoleAppender">
    <encoder class="net.logstash.logback.encoder.LogstashEncoder"/>
</appender>
```

**Result**: Machine-readable logs, easier to query in ELK stack

#### 3. Metrics (1 week)
**Add Micrometer + Prometheus**:
```xml
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

**Custom Metrics**:
```java
@Service
public class OrderService {
    private final Counter orderCounter;
    private final Timer orderProcessingTimer;
    
    public OrderService(MeterRegistry registry) {
        this.orderCounter = registry.counter("orders.created");
        this.orderProcessingTimer = registry.timer("orders.processing.time");
    }
    
    public Order processOrder(...) {
        return orderProcessingTimer.record(() -> {
            Order order = doProcessOrder(...);
            orderCounter.increment();
            return order;
        });
    }
}
```

**Result**: Real-time metrics, alerting on anomalies

#### 4. Alerting (2 days)
**Define Alerts**:
```yaml
# Prometheus alerts
groups:
  - name: shopizer
    rules:
      - alert: HighErrorRate
        expr: rate(http_server_requests_seconds_count{status="500"}[5m]) > 0.05
        annotations:
          summary: "High error rate detected"
      
      - alert: SlowOrderProcessing
        expr: histogram_quantile(0.95, orders_processing_time_seconds) > 10
        annotations:
          summary: "Order processing is slow"
```

**Result**: Proactive incident detection

---

## CONCLUSION

### Summary of Findings

**Shopizer is a mature, feature-rich e-commerce platform with**:
- ✅ Clean layered architecture
- ✅ Comprehensive REST API
- ✅ Multi-tenancy support
- ✅ Extensible module system
- ✅ Production-ready infrastructure (Docker, caching, search)

**However, it suffers from**:
- ❌ Anemic domain model (logic in services, not entities)
- ❌ God services (400-1100 lines, mixed concerns)
- ❌ Long transactions with external calls (payment, email)
- ❌ Race conditions in inventory management
- ❌ Incomplete module implementations (100+ TODOs)
- ❌ Security risks (JWT secret in config, no token revocation)
- ❌ Scalability bottlenecks (synchronous processing, N+1 queries)

### Recommended Next Steps

**Immediate (1-2 weeks)**:
1. Externalize JWT secret
2. Add optimistic locking to inventory
3. Add cart cleanup job
4. Add correlation IDs for tracing

**Short-term (1-3 months)**:
1. Refactor order processing (extract payment, inventory, email)
2. Add circuit breakers for external services
3. Implement observability (tracing, structured logging, metrics)
4. Add comprehensive integration tests

**Long-term (6-12 months)**:
1. Migrate to event-driven architecture
2. Enrich domain model (move logic to entities)
3. Extract microservices (if needed for scale)
4. Implement saga pattern for distributed transactions

### Final Assessment

**Refactoring Difficulty**: 🔴 **HIGH**  
**Business Value**: 🟢 **HIGH**  
**Technical Debt**: 🟡 **MEDIUM-HIGH**  
**Production Readiness**: 🟡 **MEDIUM** (works but has risks)

**Recommendation**: **Incremental refactoring** using strangler pattern. Do NOT attempt big-bang rewrite. Focus on high-risk areas first (inventory, security, transactions), then gradually improve architecture.

---

**End of Analysis**  
**Generated**: 2026-02-25  
**Analyst**: Senior Software Architect & Reverse Engineering Expert
