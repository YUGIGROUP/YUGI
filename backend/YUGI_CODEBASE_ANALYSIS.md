# YUGI Codebase Analysis - AI/Intelligence Layer Integration Guide

**Generated:** March 9, 2026  
**Purpose:** Comprehensive codebase documentation for integrating AI/intelligence layer for class recommendations, personalization, and ranking

---

## 1. Tech Stack & Architecture

### Backend (Node.js/Express)

**Language & Framework:**
- **Node.js** (v16+)
- **Express.js** (v4.18.2)
- **MongoDB** with **Mongoose** (v8.0.3) - Primary database
- **JWT** (jsonwebtoken v9.0.2) - Authentication

**Key Dependencies:**
- `express-validator` - Request validation
- `bcryptjs` - Password hashing
- `axios` - HTTP client for external APIs
- `stripe` (v14.9.0) - Payment processing
- `@aws-sdk/client-ses` / `@sendgrid/mail` / `nodemailer` - Email services
- `multer` - File uploads
- `helmet`, `cors`, `compression` - Security & performance

**Database:**
- **MongoDB** (MongoDB Atlas or local)
- Schema-based with Mongoose ODM
- In-memory fallback storage for development (`src/utils/inMemoryStorage.js`)

**Authentication:**
- JWT-based token authentication
- Role-based access control: `parent`, `provider`, `admin`, `other`
- Middleware: `protect`, `optionalAuth`, `requireUserType`, `requireProviderVerification`

**Third-Party Integrations:**
- **Stripe** - Payment processing (payment intents, webhooks, refunds)
- **Google Places API** - Venue data, parking info, transit stations, accessibility
- **Foursquare API** - Alternative venue data source
- **Firebase** - iOS app authentication (Firebase UID support)
- **Email Services** - AWS SES / SendGrid / Nodemailer

**Networking:**
- RESTful API architecture
- Base URL: `https://yugi-production.up.railway.app/api` (production)
- Development: `localhost:3001` or `192.168.1.72:3001`

### iOS App (Swift/SwiftUI)

**Language & Framework:**
- **Swift** (latest)
- **SwiftUI** - UI framework
- **Combine** - Reactive programming for networking
- **Firebase** - Authentication (Firebase UID)

**Key Components:**
- **APIService** (singleton) - Centralized networking layer
- **ViewModels** - MVVM architecture (e.g., `ClassDiscoveryViewModel`)
- **Models** - Swift structs matching backend schemas
- **Services** - `HybridAIService` for venue analysis, `BookingService` for bookings

**Networking:**
- **URLSession** - Native iOS networking
- Combine publishers for reactive data flow
- Custom `APIService` wrapper

**Storage:**
- `NewClassStorage` - Local storage for newly created classes
- UserDefaults for preferences
- Core Data / Firebase (if used)

---

## 2. Data Models

### Backend Models (MongoDB/Mongoose)

#### **User Model** (`src/models/User.js`)

```javascript
{
  // Basic Info
  email: String (unique, required, lowercase)
  password: String (required, minlength: 8, hashed with bcrypt)
  fullName: String (required)
  userType: Enum ['parent', 'provider', 'other', 'admin'] (required)
  
  // Profile
  profileImage: String (optional)
  phoneNumber: String (optional)
  
  // Provider-specific
  businessName: String
  businessAddress: String
  qualifications: String
  dbsCertificate: String
  bio: String
  services: String
  verificationStatus: Enum ['pending', 'underReview', 'approved', 'rejected']
  verificationDate: Date
  rejectionReason: String
  
  // Parent-specific
  children: [{
    name: String
    age: Number
    dateOfBirth: Date
  }]
  
  // Account Status
  isActive: Boolean (default: true)
  isEmailVerified: Boolean (default: false)
  
  // Password Reset
  resetPasswordToken: String
  resetPasswordExpires: Date
  
  // Timestamps
  createdAt: Date
  updatedAt: Date
}
```

#### **Class Model** (`src/models/Class.js`)

```javascript
{
  // Basic Info
  name: String (required, trim)
  description: String (required)
  category: Enum ['baby', 'toddler', 'wellness', 'Baby', 'Toddler', 'Wellness'] (required, normalized)
  
  // Provider
  provider: ObjectId (ref: 'User', required)
  
  // Media
  images: [String] (default: [])
  
  // Pricing & Capacity
  price: Number (required, min: 0)
  adultsPaySame: Boolean (default: true)
  adultPrice: Number (default: 0, min: 0)
  adultsFree: Boolean (default: false)
  individualChildSpots: Number (default: 0, min: 0, max: 15)
  siblingPairs: Number (default: 0, min: 0, max: 15)
  siblingPrice: Number (default: 0, min: 0)
  maxCapacity: Number (required, min: 1)
  currentBookings: Number (default: 0)
  
  // Schedule
  recurringDays: [Enum ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']]
  classDates: [Date]
  timeSlots: [{
    startTime: String (required)
    endTime: String (required)
  }]
  duration: Number (required, min: 15) // in minutes
  
  // Location - CRITICAL for AI/Logistics
  location: {
    name: String (default: '')
    address: {
      street: String
      city: String
      state: String
      postalCode: String
      country: String (default: 'United Kingdom')
      formatted: String
    }
    coordinates: {
      latitude: Number (default: 0)
      longitude: Number (default: 0)
    }
    accessibilityNotes: String (default: '')
    parkingInfo: String (default: '') // Contains parking + transit station info
    babyChangingFacilities: String (default: '')
  }
  
  // Class Details
  ageRange: String (default: 'All ages')
  whatToBring: String
  specialRequirements: String
  accessibilityNotes: String
  
  // Status & Reviews
  isActive: Boolean (default: true)
  isPublished: Boolean (default: false)
  averageRating: Number (default: 0, min: 0, max: 5)
  totalReviews: Number (default: 0)
  
  // Timestamps
  createdAt: Date
  updatedAt: Date
}

// Virtual Properties
availableSpots: maxCapacity - currentBookings
isFull: currentBookings >= maxCapacity

// Indexes
{ name: 'text', description: 'text' } // Text search
{ category: 1, isActive: 1, isPublished: 1 }
{ provider: 1, isActive: 1 }
```

#### **Booking Model** (`src/models/Booking.js`)

```javascript
{
  // Booking Info
  bookingNumber: String (unique, required, format: YUGI{YY}{MM}{DD}{SEQ})
  
  // Participants
  parent: ObjectId (ref: 'User', required)
  children: [{
    name: String
    age: Number
  }]
  
  // Class Info
  class: ObjectId (ref: 'Class', required)
  
  // Session Details
  sessionDate: Date (required)
  sessionTime: String (required)
  
  // Pricing
  basePrice: Number (required)
  serviceFee: Number (default: 1.99)
  totalAmount: Number (required)
  
  // Payment Info
  paymentStatus: Enum ['pending', 'paid', 'failed', 'refunded', 'held'] (default: 'pending')
  stripePaymentIntentId: String
  stripeChargeId: String
  
  // 3-Day Holding Period
  paymentDate: Date
  classCompletedAt: Date
  fundsReleaseDate: Date
  fundsReleased: Boolean (default: false)
  fundsReleasedAt: Date
  
  // Booking Status
  status: Enum ['confirmed', 'pending', 'cancelled', 'completed'] (default: 'pending')
  
  // Cancellation
  cancelledAt: Date
  cancellationReason: String
  refundAmount: Number (default: 0)
  
  // Notes
  specialRequests: String
  
  // Timestamps
  createdAt: Date
  updatedAt: Date
}

// Indexes
{ parent: 1, createdAt: -1 }
{ class: 1, sessionDate: 1 }
{ bookingNumber: 1 }
{ paymentStatus: 1, status: 1 }
```

### iOS Models (Swift)

#### **Class Model** (`Models/ClassModels.swift`)

```swift
struct Class: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let category: ClassCategory
    let provider: String // Provider ID
    let providerName: String?
    let location: Location
    let schedule: Schedule
    let pricing: Pricing
    let maxCapacity: Int
    var currentEnrollment: Int
    let averageRating: Double
    let ageRange: String
    var isFavorite: Bool
    let isActive: Bool
    
    var isAvailable: Bool { currentEnrollment < maxCapacity }
}

struct Location: Codable {
    let id: String?
    let name: String
    let address: Address
    let coordinates: Coordinates?
    let accessibilityNotes: String
    let parkingInfo: String // Contains parking + transit info
    let babyChangingFacilities: String
}

struct Address: Codable {
    let street: String
    let city: String
    let state: String
    let postalCode: String
    let country: String
    var formatted: String { "\(street), \(city), \(postalCode)" }
}

struct Schedule: Codable {
    let startDate: Date
    let endDate: Date?
    let recurringDays: [WeekDay]
    let timeSlots: [TimeSlot]
    var totalSessions: Int
}

struct Pricing: Codable {
    let amount: Double
    let currency: String
    let type: PricingType
    let description: String?
}

enum ClassCategory: String, Codable {
    case baby = "Baby"
    case toddler = "Toddler"
    case wellness = "Wellness"
}
```

#### **User Model** (`Models/User.swift`)

```swift
struct User: Codable {
    let id: String
    let email: String
    let fullName: String
    let userType: UserType
    let profileImage: String?
    let phoneNumber: String?
    let businessName: String?
    let businessAddress: String?
    let qualifications: String?
    let dbsCertificate: String?
    let bio: String?
    let services: String?
    let verificationStatus: String?
    let children: [Child]
    let isActive: Bool
    let isEmailVerified: Bool
    let location: UserLocation?
}

struct Child: Codable {
    let id: String
    let name: String
    let age: Int
    let dateOfBirth: Date?
}
```

#### **Booking Model** (`Models/ClassModels.swift`)

```swift
struct Booking: Codable {
    let id: String
    let classId: String
    let userId: String
    let status: BookingStatus
    let bookingDate: Date
    let numberOfParticipants: Int
    let selectedChildren: [Child]
    let specialRequirements: String?
    let attended: Bool
    let calendar: Calendar?
    let mongoObjectId: String?
}

struct EnhancedBooking: Codable {
    let booking: Booking
    let class: Class
    var providerName: String { /* TODO: Implement provider name lookup */ }
}
```

### Enums

**Backend:**
- `userType`: `'parent'`, `'provider'`, `'other'`, `'admin'`
- `category`: `'baby'`, `'toddler'`, `'wellness'` (normalized to capitalized)
- `verificationStatus`: `'pending'`, `'underReview'`, `'approved'`, `'rejected'`
- `paymentStatus`: `'pending'`, `'paid'`, `'failed'`, `'refunded'`, `'held'`
- `bookingStatus`: `'confirmed'`, `'pending'`, `'cancelled'`, `'completed'`
- `recurringDays`: `'monday'`, `'tuesday'`, `'wednesday'`, `'thursday'`, `'friday'`, `'saturday'`, `'sunday'`

**iOS:**
- `ClassCategory`: `.baby`, `.toddler`, `.wellness`
- `UserType`: `.parent`, `.provider`, `.other`
- `BookingStatus`: `.draft`, `.pending`, `.upcoming`, `.inProgress`, `.completed`, `.cancelled`
- `WeekDay`: Enum for days of week
- `PricingType`: `.perSession`, `.perMonth`, `.package`

---

## 3. Current App Flow

### Main User Journey (Parent)

1. **App Launch** → `WelcomeScreen` → `AuthScreen`
2. **Authentication** → Login/Signup (Firebase or email/password)
3. **Parent Dashboard** → `ParentDashboardScreen`
4. **Class Discovery** → `ClassDiscoveryView` (main entry point)
   - Shows all published classes
   - Search bar + category filter
   - `ClassDiscoveryViewModel` fetches classes via `APIService.shared.fetchClasses()`
   - Filters locally: search text (name/description) + category
5. **Class Details** → Tap `ClassCard` → Shows class details
6. **Booking Flow** → `BookingView`
   - Select children
   - Choose session date/time
   - Payment (Stripe)
   - Create booking via `POST /api/bookings`
7. **Venue Analysis** → `AIAnalysisView` / `VenueAnalysisScreen`
   - AI venue check (parking, baby changing, accessibility)
   - Calls `POST /api/classes/venues/analyze`
   - Uses `HybridAIService` (Google Places, Foursquare, fallbacks)

### Provider Flow

1. **Provider Dashboard** → `ProviderDashboardScreen`
2. **Create Class** → Form with class details, location, schedule
3. **Venue Analysis** → When adding location, analyzes venue
4. **Publish Class** → `POST /api/classes/:id/publish`
5. **Manage Bookings** → `ProviderBookingsScreen`
6. **Analytics** → `GET /api/providers/analytics`

### Current Discovery/Filtering Logic

**Backend (`GET /api/classes`):**
- Filters: `category`, `search` (text search on name/description), `minPrice`, `maxPrice`, `ageRange`, `location`
- Sorting: `createdAt: -1` (newest first)
- Pagination: `page`, `limit` (default: 20)
- Returns: Only `isActive: true` AND `isPublished: true` classes

**iOS (`ClassDiscoveryViewModel`):**
- Fetches all classes via `APIService.shared.fetchClasses()`
- Local filtering:
  - Search: `name` or `description` contains `searchText` (case-insensitive)
  - Category: `selectedCategory == nil` OR `classItem.category == selectedCategory`
- Merges with `NewClassStorage` (newly created classes shown first)

**ClassSearchView:**
- UI has filters: location, category, days
- **ISSUE:** Filters are NOT passed to `fetchClasses()` API call
- Uses mock data in some cases (`ProviderClassSearchView`)

### Ranking/Sorting

**Current Sorting:**
- Backend: `createdAt: -1` (newest first)
- iOS Bookings: `bookingDate` descending (upcoming ascending)
- No explicit ranking or recommendation logic

**No Personalization:**
- No user preference tracking
- No behavioral data collection
- No recommendation engine
- Classes shown in API order or filtered order

---

## 4. What Exists vs What's Missing

### ✅ Fully Built Features

1. **User Authentication & Authorization**
   - JWT-based auth
   - Firebase UID support
   - Role-based access control
   - Password reset flow

2. **Class Management**
   - CRUD operations
   - Publishing/unpublishing
   - Category filtering
   - Text search
   - Image uploads

3. **Booking System**
   - Create bookings
   - Status tracking
   - Cancellation with refunds
   - Capacity management
   - 3-day holding period for payments

4. **Payment Processing**
   - Stripe integration
   - Payment intents
   - Webhooks
   - Refunds
   - Service fees

5. **Venue Analysis (AI-Enhanced)**
   - `HybridAIService` for venue data
   - Google Places API integration
   - Foursquare API fallback
   - Transit station lookup
   - Parking info generation
   - Baby changing facilities detection
   - Accessibility notes
   - Caching (24-hour expiry)

6. **Provider Dashboard**
   - Analytics endpoint
   - Booking management
   - Verification system

### ⚠️ Partially Built / Stubbed

1. **Class Search**
   - UI has location/category/day filters
   - **NOT sent to backend API**
   - `ClassSearchView` doesn't pass filters to `fetchClasses()`

2. **Price Filtering**
   - Backend supports `minPrice`/`maxPrice`
   - iOS `APIService.fetchClasses()` accepts parameters
   - **NOT used in query construction**

3. **Provider Name Lookup**
   - `EnhancedBooking.providerName` has TODO comment
   - Falls back to `"Provider \(id)"`

4. **AI Recommendations**
   - `VenueAnalysisScreen.generateRecommendations()` exists
   - Simple rule-based (e.g., "Arrive 10 minutes early")
   - **No ML-based recommendations**

### ❌ Missing Features (Critical for AI Layer)

1. **No Ranking/Recommendation Engine**
   - No scoring algorithm
   - No personalization
   - No collaborative filtering
   - No content-based filtering

2. **No Behavioral Data Collection**
   - No search query logging
   - No view tracking
   - No click-through tracking
   - No booking conversion tracking
   - No cancellation reason analysis

3. **No User Preference Storage**
   - No saved preferences
   - No favorite classes tracking (UI has `isFavorite` but no persistence)
   - No location preferences
   - No price range preferences
   - No time/day preferences

4. **No Analytics for Discovery**
   - No "classes viewed" tracking
   - No "time spent viewing" metrics
   - No "classes clicked but not booked" tracking
   - No "search queries with no results" tracking

5. **No Personalization Data**
   - No child age-based recommendations
   - No location-based recommendations
   - No past booking history analysis
   - No provider preference tracking

---

## 5. Data Currently Being Captured

### Booking Data

**When Booking Created (`POST /api/bookings`):**
- `parent` (user ID)
- `class` (class ID)
- `children` (array with name, age)
- `sessionDate`, `sessionTime`
- `basePrice`, `serviceFee`, `totalAmount`
- `specialRequests`
- `bookingNumber` (auto-generated)
- `status: 'pending'`
- `paymentStatus: 'pending'`

**When Booking Cancelled (`PUT /api/bookings/:id/cancel`):**
- `status: 'cancelled'`
- `cancelledAt: Date`
- `cancellationReason: String`
- `refundAmount: Number`

**When Booking Completed (`PUT /api/bookings/:id/complete`):**
- `status: 'completed'`
- `classCompletedAt: Date`
- `fundsReleaseDate: Date` (3 days after completion)

### Venue/Logistics Data

**Per Class Location (`Class.location`):**
- `name` (venue name)
- `address` (street, city, state, postalCode, country)
- `coordinates` (latitude, longitude)
- `accessibilityNotes` (string)
- `parkingInfo` (string) - **Contains parking + nearest transit stations**
- `babyChangingFacilities` (string)

**Venue Analysis (`POST /api/classes/venues/analyze`):**
- Fetches from Google Places API
- Finds nearby transit stations (within 1500m)
- Generates parking info with transit stations
- Caches for 24 hours
- Returns: `parkingInfo`, `babyChangingFacilities`, `accessibilityNotes`, `coordinates`, `source`, `lastUpdated`

### User Data

**User Profile:**
- `email`, `fullName`, `userType`
- `children` (name, age, dateOfBirth)
- `location` (lat, lng) - **If provided**
- `phoneNumber`, `profileImage`

**Provider Data:**
- `businessName`, `businessAddress`
- `qualifications`, `dbsCertificate`
- `verificationStatus`
- `bio`, `services`

### Class Data

**Per Class:**
- `name`, `description`, `category`
- `price`, `maxCapacity`, `currentBookings`
- `ageRange`, `duration`
- `recurringDays`, `timeSlots`, `classDates`
- `location` (full venue data)
- `averageRating`, `totalReviews`
- `isActive`, `isPublished`

### ❌ Data NOT Being Captured (But Would Be Useful)

1. **Search Behavior**
   - Search queries (what parents search for)
   - Filters used (category, price, location)
   - Search results clicked
   - Searches with no results

2. **Viewing Behavior**
   - Classes viewed (which classes parents look at)
   - Time spent viewing each class
   - Classes viewed but not booked
   - Classes favorited (UI has `isFavorite` but no API)

3. **Booking Behavior**
   - Booking attempts (even if failed)
   - Payment failures
   - Booking abandonment (started but not completed)
   - Preferred booking times/days

4. **Engagement Metrics**
   - Classes shared
   - Provider ratings/reviews (schema exists but no endpoints)
   - Repeat bookings (same class, same provider)
   - Provider switching behavior

5. **Location Data**
   - User's current location (for distance-based recommendations)
   - Preferred search radius
   - Travel patterns (where parents book classes)

6. **Child-Specific Data**
   - Child age preferences (what ages parents book for)
   - Child interests (if any)
   - Sibling booking patterns

---

## 6. API & Integration Points

### Existing API Endpoints

#### **Classes**

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/api/classes` | GET | Optional | Get all published classes (supports: category, search, minPrice, maxPrice, ageRange, location, page, limit) |
| `/api/classes/:id` | GET | Public | Get specific class |
| `/api/classes` | POST | Provider | Create class |
| `/api/classes/:id` | PUT | Provider | Update class |
| `/api/classes/:id/publish` | POST | Provider | Publish class |
| `/api/classes/:id/unpublish` | POST | Provider | Unpublish class |
| `/api/classes/:id/cancel` | PUT | Provider | Cancel class |
| `/api/classes/:id` | DELETE | Provider | Delete class |
| `/api/classes/provider/my-classes` | GET | Provider | Get provider's classes |
| `/api/classes/venues/analyze` | POST | Private | Analyze venue (parking, transit, accessibility) |

#### **Bookings**

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/api/bookings` | POST | Parent/Provider | Create booking |
| `/api/bookings` | GET | Private | Get user's bookings (supports: status, page, limit) |
| `/api/bookings/:id` | GET | Private | Get specific booking |
| `/api/bookings/:id/cancel` | PUT | Private | Cancel booking |
| `/api/bookings/:id/confirm` | PUT | Provider | Confirm booking |
| `/api/bookings/:id/complete` | PUT | Provider | Mark booking as completed |

#### **Payments**

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/api/payments/create-payment-intent` | POST | Private | Create Stripe payment intent |
| `/api/payments/confirm-payment` | POST | Private | Confirm payment |
| `/api/payments/webhook` | POST | Stripe | Stripe webhook handler |
| `/api/payments/refund` | POST | Private | Process refund |
| `/api/payments/payment-methods` | GET | Private | Get saved payment methods |
| `/api/payments/held-funds` | GET | Provider | Get held funds |
| `/api/payments/mark-class-completed` | POST | Provider | Mark class completed (release funds) |

#### **Auth**

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/api/auth/signup` | POST | Public | Register user |
| `/api/auth/login` | POST | Public | Login (email/password or Firebase UID) |
| `/api/auth/me` | GET | Private | Get current user |
| `/api/auth/upload-documents` | POST | Provider | Upload verification documents |
| `/api/auth/change-password` | POST | Private | Change password |
| `/api/auth/forgot-password` | POST | Public | Request password reset |
| `/api/auth/reset-password` | POST | Public | Reset password |

#### **Users**

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/api/users/provider/:id` | GET | Public | Get provider profile |
| `/api/users/profile` | PUT | Private | Update user profile |
| `/api/users/children` | POST | Parent | Add child |
| `/api/users/children/:childId` | PUT | Parent | Update child |
| `/api/users/children/:childId` | DELETE | Parent | Delete child |
| `/api/users/:id/userType` | PUT | Admin | Update user type |

#### **Providers**

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/api/providers/dashboard` | GET | Provider | Get provider dashboard |
| `/api/providers/business-info` | PUT | Provider | Update business info |
| `/api/providers/verification-status` | GET | Provider | Get verification status |
| `/api/providers/request-verification` | POST | Provider | Request verification |
| `/api/providers/analytics` | GET | Provider | Get analytics |

#### **Admin**

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/api/admin/providers/pending` | GET | Admin | Get pending providers |
| `/api/admin/providers/:id` | GET | Admin | Get provider details |
| `/api/admin/providers/:id/verify` | PUT | Admin | Approve/reject provider |
| `/api/admin/dashboard` | GET | Admin | Admin dashboard |
| `/api/admin/providers` | GET | Admin | Get all providers |

### Integration Points for AI/Recommendation Service

#### **1. Class Discovery Endpoint Enhancement**

**Current:** `GET /api/classes`
- Supports: `category`, `search`, `minPrice`, `maxPrice`, `ageRange`, `location`, `page`, `limit`
- Sorting: `createdAt: -1` (newest first)

**Proposed Enhancement:**
```javascript
GET /api/classes?userId={userId}&recommend=true&limit=20
```

**New Query Parameters:**
- `userId` - For personalization
- `recommend` - Boolean to enable AI ranking
- `latitude`, `longitude` - User location for distance-based ranking
- `childAge` - Child age for age-appropriate recommendations
- `preferences` - JSON string of user preferences

**Response Enhancement:**
```json
{
  "success": true,
  "data": [
    {
      "class": { /* class data */ },
      "score": 0.95,
      "reasons": ["Matches your child's age", "Near your location", "Highly rated"]
    }
  ],
  "pagination": { /* ... */ }
}
```

#### **2. New Recommendation Endpoint**

**Proposed:** `GET /api/recommendations`
```javascript
GET /api/recommendations?userId={userId}&limit=20&category={category}
```

**Returns:**
- Personalized class recommendations
- Ranking scores
- Explanation reasons

#### **3. Behavioral Data Collection Endpoints**

**Proposed:** `POST /api/analytics/events`
```javascript
POST /api/analytics/events
{
  "userId": "user_id",
  "eventType": "class_viewed" | "class_searched" | "booking_started" | "booking_completed" | "class_favorited",
  "classId": "class_id",
  "metadata": {
    "searchQuery": "...",
    "filters": { "category": "...", "price": "..." },
    "timeSpent": 30,
    "source": "discovery" | "search" | "recommendation"
  }
}
```

#### **4. User Preferences Endpoint**

**Proposed:** `PUT /api/users/preferences`
```javascript
PUT /api/users/preferences
{
  "preferredCategories": ["baby", "toddler"],
  "preferredPriceRange": { "min": 10, "max": 50 },
  "preferredDays": ["monday", "wednesday"],
  "preferredTimes": ["morning", "afternoon"],
  "searchRadius": 10, // km
  "location": { "latitude": 51.5074, "longitude": -0.1278 }
}
```

### Data Flow Between App and Backend

**Current Flow:**
1. iOS app calls `APIService.shared.fetchClasses()`
2. Makes HTTP GET to `/api/classes`
3. Backend queries MongoDB with filters
4. Returns JSON array of classes
5. iOS transforms to Swift models
6. `ClassDiscoveryViewModel` filters locally

**Proposed AI Integration Flow:**
1. iOS app calls `APIService.shared.fetchClasses(userId: ..., recommend: true)`
2. Makes HTTP GET to `/api/classes?userId=...&recommend=true`
3. Backend:
   - Fetches classes from MongoDB
   - Calls AI recommendation service (external or internal)
   - Ranks classes by score
   - Returns ranked list with scores/reasons
4. iOS displays ranked classes with explanation badges

---

## 7. File Structure

### Backend Structure

```
backend/
├── src/
│   ├── models/
│   │   ├── User.js              # User schema
│   │   ├── Class.js             # Class schema (CRITICAL for AI)
│   │   └── Booking.js           # Booking schema
│   ├── routes/
│   │   ├── classes.js           # Class endpoints (MAIN for discovery)
│   │   ├── bookings.js          # Booking endpoints
│   │   ├── payments.js          # Payment endpoints
│   │   ├── auth.js              # Authentication endpoints
│   │   ├── users.js             # User profile endpoints
│   │   ├── providers.js         # Provider endpoints
│   │   └── admin.js             # Admin endpoints
│   ├── services/
│   │   ├── venueDataService.js  # Venue analysis (AI-enhanced)
│   │   └── emailService.js      # Email sending
│   ├── middleware/
│   │   └── auth.js              # Authentication middleware
│   ├── utils/
│   │   ├── inMemoryStorage.js   # Dev fallback storage
│   │   └── emailTemplates.js    # Email templates
│   └── server.js                # Express app setup
├── config/
│   └── database.js              # MongoDB connection
├── scripts/
│   ├── createAdmin.js           # Admin user creation
│   └── updateClassDates.js      # Utility scripts
├── package.json
└── README.md
```

### iOS Structure (Key Files for AI Integration)

```
YUGI/
├── YUGI/
│   ├── Models/
│   │   ├── ClassModels.swift          # Class data models (CRITICAL)
│   │   ├── User.swift                 # User models
│   │   ├── ClassSearchModel.swift     # Search models
│   │   ├── ClassCategory.swift        # Category enum
│   │   └── ProviderModels.swift       # Provider models
│   ├── ViewModels/
│   │   └── ClassDiscoveryViewModel.swift  # Discovery logic (CRITICAL)
│   ├── Screens/
│   │   ├── ClassDiscoveryView.swift       # Main discovery UI (CRITICAL)
│   │   ├── ClassSearchView.swift          # Search UI (needs filter fix)
│   │   ├── BookingView.swift              # Booking flow
│   │   ├── VenueAnalysisScreen.swift     # AI venue analysis
│   │   └── AIAnalysisView.swift           # AI venue check UI
│   ├── Services/
│   │   ├── APIService.swift               # Networking (CRITICAL)
│   │   └── HybridAIService.swift         # Venue AI service
│   ├── Views/
│   │   └── Components/                   # Reusable UI components
│   ├── Utils/
│   │   ├── ImageCompressor.swift
│   │   └── ImagePicker.swift
│   └── Config/
│       └── AppConfig.swift                # App configuration
└── YUGI.xcodeproj
```

### Most Relevant Files for AI/Intelligence Layer

**Backend:**
1. `src/routes/classes.js` - **PRIMARY** - Class discovery endpoint (line 489: `GET /api/classes`)
2. `src/models/Class.js` - Class schema (location data critical)
3. `src/models/Booking.js` - Booking history for recommendations
4. `src/models/User.js` - User preferences/children data
5. `src/services/venueDataService.js` - Venue analysis (already AI-enhanced)

**iOS:**
1. `ViewModels/ClassDiscoveryViewModel.swift` - **PRIMARY** - Discovery logic
2. `Screens/ClassDiscoveryView.swift` - **PRIMARY** - Discovery UI
3. `Services/APIService.swift` - **PRIMARY** - Networking layer
4. `Models/ClassModels.swift` - Data models
5. `Screens/ClassSearchView.swift` - Search UI (needs filter integration)

---

## 8. Key Insights for AI Integration

### Strengths

1. **Rich Venue Data**: Already collecting parking, transit, accessibility, baby changing facilities
2. **Structured Data Models**: Well-defined schemas for classes, bookings, users
3. **Booking History**: Complete booking data available for collaborative filtering
4. **Location Data**: Coordinates available for distance-based recommendations
5. **Category System**: Clear categorization (baby, toddler, wellness)

### Gaps

1. **No Behavioral Tracking**: No search/view/click tracking
2. **No User Preferences**: No saved preferences system
3. **No Ranking Logic**: Simple date-based sorting only
4. **Filter Gaps**: iOS filters not sent to backend
5. **No Recommendation Engine**: No ML-based recommendations

### Recommended Integration Points

1. **Enhance `GET /api/classes`** with recommendation scoring
2. **Add behavioral tracking endpoints** for data collection
3. **Create user preferences system** for personalization
4. **Build recommendation service** (external or internal)
5. **Fix iOS filter integration** to send filters to backend
6. **Add ranking scores** to API responses
7. **Implement explanation system** for recommendations

### Data Available for Training

- **User Data**: Children ages, location, booking history
- **Class Data**: Categories, prices, locations, schedules, ratings
- **Booking Data**: What parents book, cancellation reasons
- **Venue Data**: Logistics data (parking, accessibility)

### Missing Data Needed

- **Search queries**: What parents search for
- **View behavior**: Which classes parents view
- **Click behavior**: Which classes parents click but don't book
- **Time preferences**: Preferred booking times/days
- **Price preferences**: Preferred price ranges
- **Location preferences**: Search radius, preferred areas

---

## 9. TODO Comments & Placeholders

### Backend

- `src/routes/users.js:27` - "TODO: Remove this temporary fix once user types are properly set"
- `src/routes/users.js:258` - "Basic users route - placeholder for now"

### iOS

- `ClassSearchView.swift:474` - "TODO: Implement AI data update functionality"
- `ClassModels.swift:429` - "TODO: Implement provider name lookup by ID"
- `BookingView.swift:1238` - "userId: UUID() // TODO: Get from auth service"
- `Config/AppConfig.swift:5` - "TODO: Replace this with your OpenAI API key"
- `TermsPrivacyScreen.swift` - Mentions "AI to recommend classes" (policy only, no implementation)

---

## 10. Next Steps for AI Integration

1. **Create Recommendation Service**
   - Build ML model or rule-based system
   - Integrate with `GET /api/classes` endpoint
   - Return ranked classes with scores

2. **Add Behavioral Tracking**
   - Create analytics endpoints
   - Track search, view, click events
   - Store in MongoDB or analytics DB

3. **Build User Preferences System**
   - Add preferences to User model
   - Create preferences endpoints
   - Use preferences in recommendations

4. **Fix iOS Filter Integration**
   - Update `ClassSearchView` to send filters to API
   - Update `APIService.fetchClasses()` to use all filters
   - Remove local filtering where possible

5. **Enhance API Responses**
   - Add ranking scores to class responses
   - Add explanation reasons
   - Add personalization indicators

6. **Implement Recommendation UI**
   - Add "Recommended for you" section
   - Show explanation badges
   - Highlight personalized classes

---

**End of Analysis**
