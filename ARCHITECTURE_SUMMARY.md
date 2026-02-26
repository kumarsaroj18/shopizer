# Shopizer E-Commerce Platform - Architecture Summary

## Executive Overview

**Shopizer** is an enterprise-grade, open-source **headless e-commerce platform** built on Java, designed for multi-tenant retail operations. It provides a complete REST API-driven backend for managing catalogs, orders, customers, payments, and shipping, enabling decoupled frontend implementations (web, mobile, IoT).

**Version**: 3.2.7  
**License**: Apache License 2.0  
**Primary Use Case**: Headless commerce, B2C/B2B e-commerce, multi-store management

---

## Technical Stack

### Core Technologies

| Layer | Technology | Version |
|-------|-----------|---------|
| **Language** | Java | 11, 17+ |
| **Framework** | Spring Boot | 2.5.12 |
| **Build Tool** | Maven | 3.x |
| **Persistence** | Spring Data JPA + Hibernate | 5.x |
| **Database** | H2 (default), MySQL, PostgreSQL, Oracle | 8.0.21 (MySQL) |
| **Cache** | Infinispan, EhCache | 9.4.18 |
| **Search** | Elasticsearch | 7.5.2 |
| **Security** | Spring Security + JWT | JWT 0.8.0 |
| **API Documentation** | Swagger/OpenAPI | 2.9.2 |
| **Rules Engine** | Drools | 7.32.0 |
| **Object Mapping** | MapStruct | 1.3.0 |

### Integration & Modules

- **Payment Gateways**: PayPal, Stripe, Braintree
- **Cloud Storage**: AWS S3, Google Cloud Storage
- **Email**: AWS SES, SMTP
- **Shipping**: Canada Post, custom integrations
- **Geolocation**: MaxMind GeoIP2
- **Maps**: Google Maps API

### Infrastructure

- **Containerization**: Docker (official images available)
- **Application Server**: Embedded Tomcat
- **Session Management**: H2 database-backed sessions
- **Monitoring**: Spring Boot Actuator

---

## Project Architecture

### Multi-Module Maven Structure

```
shopizer (parent)
├── sm-core-model          # Domain entities (JPA models)
├── sm-core-modules        # Integration modules (payment, shipping, email, CMS)
├── sm-core                # Business logic & services layer
├── sm-shop-model          # REST API DTOs (request/response models)
└── sm-shop                # Web layer (REST controllers, security, config)
```

### Module Responsibilities

#### 1. **sm-core-model** (Domain Layer)
- JPA entity definitions
- Core business domain objects
- Database schema mapping
- Key entities:
  - `Product`, `Category`, `Manufacturer`
  - `Customer`, `Order`, `ShoppingCart`
  - `MerchantStore` (multi-tenancy)
  - `User`, `Group`, `Permission`
  - `Payment`, `Shipping`, `Tax`

#### 2. **sm-core-modules** (Integration Layer)
- External system integrations
- Payment processors (PayPal, Stripe, Braintree)
- Shipping providers
- Email service providers
- CMS/file storage (S3, GCS, local)
- Order total calculators

#### 3. **sm-core** (Business Logic Layer)
- Service interfaces and implementations
- Repository interfaces (Spring Data JPA)
- Business rules and validation
- Transaction management
- Key service domains:
  - Catalog services (product, category, manufacturer)
  - Order management
  - Customer management
  - User/authentication services
  - Payment & shipping services
  - Tax calculation
  - Search services
  - Content management

#### 4. **sm-shop-model** (API Contract Layer)
- REST API DTOs
- Request/response models
- API validation annotations
- Separation of internal models from API contracts

#### 5. **sm-shop** (Presentation/API Layer)
- REST API controllers (v0, v1, v2)
- Spring Security configuration
- JWT authentication
- Swagger documentation
- Request/response mapping (MapStruct)
- Exception handling
- CORS configuration
- XSS protection (OWASP AntiSamy)

---

## Architectural Patterns

### 1. **Layered Architecture**
```
┌─────────────────────────────────────────┐
│   REST API Layer (sm-shop)              │
│   - Controllers                          │
│   - Security (JWT)                       │
│   - Exception Handlers                   │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│   Facade Layer (sm-shop)                │
│   - Business facades                     │
│   - DTO mapping (MapStruct)              │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│   Service Layer (sm-core)               │
│   - Business logic                       │
│   - Transaction management               │
│   - Validation                           │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│   Repository Layer (sm-core)            │
│   - Spring Data JPA repositories        │
│   - Query methods                        │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│   Data Layer (sm-core-model)            │
│   - JPA Entities                         │
│   - Database schema                      │
└─────────────────────────────────────────┘
```

### 2. **Hexagonal Architecture (Ports & Adapters)**
- Core business logic isolated in `sm-core`
- External integrations abstracted via interfaces in `sm-core-modules`
- Multiple adapters: REST API, payment gateways, storage providers

### 3. **Multi-Tenancy**
- Store-based isolation via `MerchantStore` entity
- All operations scoped to merchant context
- Supports multiple stores in single deployment

### 4. **API Versioning**
- `/api/v0/*` - Legacy endpoints
- `/api/v1/*` - Current stable API
- `/api/v2/*` - Next-generation endpoints (product variations)

---

## System Flow Diagrams

### High-Level Request Flow

```
┌──────────┐         ┌──────────────┐         ┌─────────────┐
│  Client  │────────▶│  API Gateway │────────▶│  sm-shop    │
│ (React/  │  HTTPS  │   (Nginx/    │   JWT   │ Controllers │
│  Mobile) │         │    ALB)      │  Auth   │             │
└──────────┘         └──────────────┘         └──────┬──────┘
                                                      │
                                              ┌───────▼────────┐
                                              │   Facades      │
                                              │  (Mapping)     │
                                              └───────┬────────┘
                                                      │
                                              ┌───────▼────────┐
                                              │  sm-core       │
                                              │  Services      │
                                              └───┬────────┬───┘
                                                  │        │
                                    ┌─────────────▼──┐  ┌─▼──────────┐
                                    │  Repositories  │  │  Modules   │
                                    │  (JPA)         │  │ (Payment,  │
                                    └────────┬───────┘  │  Shipping) │
                                             │          └─────┬──────┘
                                    ┌────────▼────────┐       │
                                    │   Database      │       │
                                    │  (MySQL/H2)     │       │
                                    └─────────────────┘       │
                                                              │
                                                    ┌─────────▼────────┐
                                                    │  External APIs   │
                                                    │ (Stripe, PayPal, │
                                                    │  AWS S3, etc.)   │
                                                    └──────────────────┘
```

### E-Commerce Transaction Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                     CUSTOMER JOURNEY                                 │
└─────────────────────────────────────────────────────────────────────┘

1. BROWSE CATALOG
   ┌──────────┐
   │ Customer │──▶ GET /api/v1/products?store=DEFAULT
   └──────────┘         │
                        ▼
              ┌─────────────────┐
              │ ProductService  │──▶ Elasticsearch (search)
              │ CategoryService │──▶ Cache (Infinispan)
              └─────────────────┘

2. ADD TO CART
   ┌──────────┐
   │ Customer │──▶ POST /api/v1/cart/DEFAULT/cart
   └──────────┘         │
                        ▼
              ┌──────────────────────┐
              │ ShoppingCartService  │──▶ Database (persist cart)
              └──────────────────────┘

3. CHECKOUT
   ┌──────────┐
   │ Customer │──▶ POST /api/v1/auth/customer/login (JWT)
   └──────────┘         │
                        ▼
              ┌──────────────────┐
              │ SecurityService  │──▶ JWT Token Generation
              └──────────────────┘
                        │
                        ▼
              POST /api/v1/order/DEFAULT
                        │
                        ▼
              ┌──────────────────┐
              │   OrderService   │
              └────────┬─────────┘
                       │
         ┌─────────────┼─────────────┐
         │             │             │
         ▼             ▼             ▼
   ┌─────────┐  ┌──────────┐  ┌──────────┐
   │  Tax    │  │ Shipping │  │  Drools  │
   │ Service │  │  Module  │  │  Rules   │
   └─────────┘  └──────────┘  └──────────┘
                       │
                       ▼
              ┌──────────────────┐
              │ PaymentService   │
              └────────┬─────────┘
                       │
                       ▼
              ┌──────────────────┐
              │ Payment Module   │──▶ Stripe/PayPal API
              │ (Stripe/PayPal)  │
              └────────┬─────────┘
                       │
                       ▼
              ┌──────────────────┐
              │ Order Confirmed  │──▶ Email Notification
              │ (Database)       │
              └──────────────────┘
```

### Authentication & Authorization Flow

```
┌──────────┐                                    ┌─────────────────┐
│  Client  │───1. POST /api/v1/auth/login ────▶│ SecurityApi     │
└──────────┘    (username/password)             └────────┬────────┘
                                                         │
                                                         ▼
                                                ┌─────────────────┐
                                                │ UserService     │
                                                │ - Validate      │
                                                │ - Load user     │
                                                └────────┬────────┘
                                                         │
                                                         ▼
                                                ┌─────────────────┐
                                                │ JWTTokenUtil    │
                                                │ - Generate JWT  │
                                                └────────┬────────┘
                                                         │
┌──────────┐                                             │
│  Client  │◀───2. JWT Token ─────────────────────────┘
└────┬─────┘
     │
     │ 3. Subsequent requests with JWT
     │
     ▼
┌─────────────────────────────────────────────────────────────┐
│  Spring Security Filter Chain                               │
│  ┌──────────────────┐    ┌──────────────────┐              │
│  │ JWTAuthFilter    │───▶│ Validate Token   │              │
│  │                  │    │ Extract Claims   │              │
│  └──────────────────┘    └────────┬─────────┘              │
│                                    │                         │
│                           ┌────────▼─────────┐              │
│                           │ SecurityContext  │              │
│                           │ (User Principal) │              │
│                           └──────────────────┘              │
└─────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                           ┌─────────────────┐
                           │ API Controller  │
                           │ @PreAuthorize   │
                           └─────────────────┘
```

### Data Flow - Product Management

```
┌─────────────────────────────────────────────────────────────────┐
│                    ADMIN PRODUCT MANAGEMENT                      │
└─────────────────────────────────────────────────────────────────┘

1. CREATE PRODUCT
   ┌───────┐
   │ Admin │──▶ POST /api/v1/private/products
   └───────┘    (PersistableProduct DTO)
                        │
                        ▼
              ┌──────────────────────┐
              │ ProductFacade        │
              │ - Validate           │
              │ - Map DTO to Entity  │
              └──────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │ ProductService       │
              │ - Business rules     │
              │ - Save product       │
              │ - Save attributes    │
              │ - Save prices        │
              └──────────┬───────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
   ┌──────────┐   ┌──────────┐   ┌──────────┐
   │ Product  │   │ Product  │   │ Product  │
   │Repository│   │Attribute │   │  Price   │
   │          │   │Repository│   │Repository│
   └────┬─────┘   └────┬─────┘   └────┬─────┘
        │              │              │
        └──────────────┼──────────────┘
                       │
                       ▼
              ┌─────────────────┐
              │   Database      │
              │   (MySQL/H2)    │
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │  Elasticsearch  │──▶ Index for search
              │  (async)        │
              └─────────────────┘

2. UPLOAD PRODUCT IMAGE
   ┌───────┐
   │ Admin │──▶ POST /api/v1/private/products/{id}/image
   └───────┘    (MultipartFile)
                        │
                        ▼
              ┌──────────────────────┐
              │ ProductImageService  │
              │ - Validate image     │
              │ - Resize/crop        │
              └──────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │ CMS Module           │
              │ (S3/GCS/Local)       │
              └──────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │ Cloud Storage        │
              │ - Store image        │
              │ - Return URL         │
              └──────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │ ProductImage Entity  │──▶ Database
              │ (URL reference)      │
              └──────────────────────┘
```

---

## Key Design Decisions

### 1. **Headless Architecture**
- Complete separation of backend and frontend
- REST API-first design
- Enables omnichannel experiences (web, mobile, IoT)
- Frontend agnostic (React, Vue, Angular, mobile apps)

### 2. **Multi-Tenancy via Merchant Store**
- Single deployment serves multiple stores
- Data isolation at application level
- Each store has independent:
  - Catalog
  - Customers
  - Orders
  - Configuration
  - Branding

### 3. **Modular Integration Layer**
- Payment, shipping, email, CMS abstracted as modules
- Easy to swap implementations
- Configuration-driven module selection

### 4. **Caching Strategy**
- Infinispan for distributed caching
- EhCache for local caching
- Cache invalidation on entity updates
- Reduces database load for catalog queries

### 5. **Search with Elasticsearch**
- Full-text product search
- Faceted navigation
- Autocomplete
- Asynchronous indexing

### 6. **Security**
- JWT-based stateless authentication
- Role-based access control (RBAC)
- Method-level security with `@PreAuthorize`
- XSS protection with OWASP AntiSamy
- Password validation with Passay

### 7. **Business Rules with Drools**
- Externalized business logic
- Tax calculation rules
- Pricing rules
- Promotion rules
- No code changes for rule updates

---

## API Structure

### REST API Endpoints (v1)

| Domain | Endpoints | Description |
|--------|-----------|-------------|
| **Products** | `/api/v1/products/*` | Product CRUD, search, reviews, images |
| **Categories** | `/api/v1/category/*` | Category hierarchy management |
| **Cart** | `/api/v1/cart/*` | Shopping cart operations |
| **Orders** | `/api/v1/order/*` | Order creation, management, history |
| **Customers** | `/api/v1/customer/*` | Customer registration, profile, addresses |
| **Users** | `/api/v1/user/*` | Admin user management |
| **Auth** | `/api/v1/auth/*` | Login, logout, token refresh |
| **Payment** | `/api/v1/payment/*` | Payment methods, processing |
| **Shipping** | `/api/v1/shipping/*` | Shipping options, rates |
| **Store** | `/api/v1/store/*` | Merchant store configuration |
| **Content** | `/api/v1/content/*` | CMS content, pages, images |
| **Tax** | `/api/v1/tax/*` | Tax classes, rates |
| **Search** | `/api/v1/search/*` | Product search |

### API Documentation
- **Swagger UI**: `http://localhost:8080/swagger-ui.html`
- Auto-generated from annotations
- Interactive API testing

---

## Database Schema Highlights

### Core Tables
- `MERCHANT_STORE` - Multi-tenant store configuration
- `PRODUCT` - Product master data
- `PRODUCT_DESCRIPTION` - Localized product content
- `PRODUCT_AVAILABILITY` - Inventory management
- `PRODUCT_PRICE` - Pricing with currency support
- `CATEGORY` - Hierarchical category structure
- `CUSTOMER` - Customer accounts
- `SHOPPING_CART` - Persistent shopping carts
- `SALES_ORDER` - Order header
- `ORDER_PRODUCT` - Order line items
- `USER` - Admin users
- `PERMISSION` - RBAC permissions

### Schema Strategy
- JPA annotations for schema generation
- Hibernate DDL auto-update (configurable)
- Support for MySQL, PostgreSQL, Oracle, H2
- Default schema: `SALESMANAGER`

---

## Configuration Profiles

Shopizer supports multiple Spring profiles for different environments:

| Profile | Purpose | Config File |
|---------|---------|-------------|
| **default** | H2 in-memory database | `application.properties` |
| **mysql** | MySQL database | `profiles/mysql/application.properties` |
| **docker** | Docker deployment | `profiles/docker/application.properties` |
| **gcp** | Google Cloud Platform | `profiles/gcp/application.properties` |
| **cloud** | Generic cloud deployment | `profiles/cloud/application.properties` |
| **local** | Local development | `profiles/local/application.properties` |

---

## Deployment Architecture

### Docker Deployment

```
┌─────────────────────────────────────────────────────────────┐
│                      Docker Compose                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │  shopizer-api    │  │  shopizer-admin  │                │
│  │  (Backend)       │  │  (Admin UI)      │                │
│  │  Port: 8080      │  │  Port: 82        │                │
│  └────────┬─────────┘  └────────┬─────────┘                │
│           │                     │                           │
│  ┌────────▼─────────────────────▼─────┐                    │
│  │  shopizer-shop-reactjs             │                    │
│  │  (Storefront)                      │                    │
│  │  Port: 80                          │                    │
│  └────────────────────────────────────┘                    │
│                                                              │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │  MySQL           │  │  Elasticsearch   │                │
│  │  Port: 3306      │  │  Port: 9200      │                │
│  └──────────────────┘  └──────────────────┘                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Cloud Deployment Options
- **AWS**: ECS/EKS + RDS + S3 + SES
- **GCP**: GKE + Cloud SQL + Cloud Storage
- **Azure**: AKS + Azure Database + Blob Storage

---

## Performance Considerations

### Optimization Strategies
1. **Caching**
   - Infinispan distributed cache
   - EhCache for local caching
   - HTTP caching headers

2. **Database**
   - Connection pooling (HikariCP)
   - Query optimization
   - Lazy loading for associations
   - Database indexing

3. **Search**
   - Elasticsearch for fast product search
   - Asynchronous indexing
   - Faceted search

4. **API**
   - Pagination for list endpoints
   - Field filtering
   - Compression (gzip)

5. **Static Assets**
   - CDN for product images
   - Cloud storage (S3/GCS)

---

## Security Features

1. **Authentication**
   - JWT tokens (stateless)
   - Separate customer and admin authentication
   - Token expiration and refresh

2. **Authorization**
   - Role-based access control (RBAC)
   - Method-level security
   - Store-level isolation

3. **Input Validation**
   - Bean Validation (JSR-303)
   - XSS protection (OWASP AntiSamy)
   - SQL injection prevention (JPA)

4. **Password Security**
   - BCrypt hashing
   - Password complexity rules (Passay)
   - Password reset flow

5. **HTTPS**
   - TLS/SSL support
   - Secure cookie flags

---

## Monitoring & Observability

### Spring Boot Actuator Endpoints
- `/actuator/health` - Health checks
- `/actuator/metrics` - Application metrics
- `/actuator/info` - Build information
- `/actuator/env` - Environment properties

### Logging
- SLF4J with Logback
- Configurable log levels
- Structured logging support

---

## Extension Points

### How to Extend Shopizer

1. **Custom Payment Gateway**
   - Implement `PaymentModule` interface
   - Register in `sm-core-modules`

2. **Custom Shipping Provider**
   - Implement `ShippingQuoteModule` interface
   - Configure in merchant store

3. **Custom Business Rules**
   - Add Drools rule files
   - No code changes required

4. **Custom API Endpoints**
   - Add controllers in `sm-shop`
   - Follow versioning convention

5. **Custom Entities**
   - Extend domain model in `sm-core-model`
   - Add repositories and services

---

## Development Workflow

### Build & Run

```bash
# Clone repository
git clone https://github.com/shopizer-ecommerce/shopizer.git

# Build all modules
cd shopizer
./mvnw clean install

# Run application
cd sm-shop
./mvnw spring-boot:run

# Access Swagger UI
open http://localhost:8080/swagger-ui.html
```

### Docker Quick Start

```bash
# Run backend
docker run -p 8080:8080 shopizerecomm/shopizer:latest

# Run admin UI
docker run -e "APP_BASE_URL=http://localhost:8080/api" \
  -p 82:80 shopizerecomm/shopizer-admin

# Run storefront
docker run -e "APP_MERCHANT=DEFAULT" \
  -e "APP_BASE_URL=http://localhost:8080" \
  -p 80:80 shopizerecomm/shopizer-shop-reactjs
```

---

## Technology Rationale

| Technology | Why Chosen |
|------------|------------|
| **Spring Boot** | Rapid development, production-ready, extensive ecosystem |
| **JPA/Hibernate** | ORM abstraction, database portability, caching |
| **Infinispan** | Distributed caching, clustering support |
| **Elasticsearch** | Full-text search, scalability, faceted navigation |
| **JWT** | Stateless authentication, scalability, mobile-friendly |
| **Drools** | Externalized business rules, non-technical rule authoring |
| **MapStruct** | Compile-time DTO mapping, performance, type safety |
| **Swagger** | API documentation, interactive testing, client generation |
| **Docker** | Consistent deployment, microservices-ready, portability |

---

## Future Roadmap Considerations

Based on the architecture, potential enhancements:

1. **Microservices Migration**
   - Split modules into independent services
   - Event-driven architecture (Kafka/RabbitMQ)

2. **GraphQL API**
   - Alternative to REST
   - Client-driven queries

3. **Reactive Stack**
   - Spring WebFlux
   - Non-blocking I/O

4. **Advanced Analytics**
   - Real-time dashboards
   - ML-based recommendations

5. **Multi-Region Deployment**
   - Geographic distribution
   - Data replication

---

## Conclusion

Shopizer is a **mature, production-ready e-commerce platform** with:
- ✅ Clean layered architecture
- ✅ Comprehensive REST API
- ✅ Multi-tenancy support
- ✅ Extensible module system
- ✅ Enterprise integrations (payment, shipping, cloud)
- ✅ Security best practices
- ✅ Docker-ready deployment
- ✅ Active development and community

**Best suited for**: Organizations needing a customizable, headless e-commerce backend with full control over the technology stack.

---

**Generated**: 2026-02-25  
**Shopizer Version**: 3.2.7  
**Documentation**: https://shopizer-ecommerce.github.io/documentation/
