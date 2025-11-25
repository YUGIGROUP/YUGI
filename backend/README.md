# YUGI Backend API

A comprehensive Node.js/Express backend for the YUGI children's class booking platform.

## 🚀 Features

- **User Authentication & Authorization**
  - JWT-based authentication
  - Role-based access control (Parent, Provider, Other)
  - Provider verification system

- **Class Management**
  - CRUD operations for classes
  - Publishing/unpublishing classes
  - Category filtering and search
  - Image upload support

- **Booking System**
  - Create and manage bookings
  - Booking status tracking
  - Cancellation with refund logic
  - Capacity management

- **Payment Processing**
  - Stripe integration
  - Payment intents and webhooks
  - Refund processing
  - Service fee handling

- **Provider Dashboard**
  - Analytics and insights
  - Booking management
  - Revenue tracking
  - Verification status

## 📋 Prerequisites

- Node.js (v16 or higher)
- MongoDB (v5 or higher)
- Stripe account (for payments)
- Email service (Gmail recommended)

## 🛠️ Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd backend
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Environment Setup**
   ```bash
   cp env.example .env
   ```
   
   Edit `.env` with your configuration:
   ```env
   NODE_ENV=development
   PORT=5000
   MONGODB_URI=mongodb://localhost:27017/yugi
   JWT_SECRET=your-super-secret-jwt-key
   STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key
   STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret
   EMAIL_HOST=smtp.gmail.com
   EMAIL_USER=your-email@gmail.com
   EMAIL_PASS=your-app-password
   ```

4. **Start the server**
   ```bash
   # Development
   npm run dev
   
   # Production
   npm start
   ```

## 📚 API Documentation

### Authentication

#### Register User
```http
POST /api/auth/signup
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123",
  "fullName": "John Doe",
  "userType": "parent",
  "phoneNumber": "+44123456789"
}
```

#### Login
```http
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123"
}
```

### Classes

#### Get All Classes
```http
GET /api/classes?category=music&minPrice=10&maxPrice=50&search=piano
Authorization: Bearer <token>
```

#### Create Class (Providers Only)
```http
POST /api/classes
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "Piano Lessons for Kids",
  "description": "Fun piano lessons for children aged 5-12",
  "category": "music",
  "price": 25.00,
  "maxCapacity": 8,
  "duration": 60,
  "totalSessions": 10,
  "ageRange": "5-12 years",
  "recurringDays": ["monday", "wednesday"],
  "timeSlots": [
    {
      "startTime": "16:00",
      "endTime": "17:00"
    }
  ]
}
```

### Bookings

#### Create Booking (Parents Only)
```http
POST /api/bookings
Authorization: Bearer <token>
Content-Type: application/json

{
  "classId": "class_id_here",
  "children": [
    {
      "name": "Emma Smith",
      "age": 7
    }
  ],
  "sessionDate": "2024-01-15T16:00:00.000Z",
  "sessionTime": "16:00",
  "specialRequests": "Emma is left-handed"
}
```

### Payments

#### Create Payment Intent
```http
POST /api/payments/create-payment-intent
Authorization: Bearer <token>
Content-Type: application/json

{
  "bookingId": "booking_id_here"
}
```

## 🔧 Database Models

### User
- Basic info (email, password, fullName)
- User type (parent, provider, other, admin)
- Provider-specific fields (business info, verification)
- Parent-specific fields (children)

### Class
- Basic info (name, description, category)
- Provider reference
- Pricing and capacity
- Schedule and location
- Status and reviews

### Booking
- Parent and class references
- Children information
- Session details
- Payment status
- Booking status

## 👨‍💼 Admin Verification System

### Overview
The admin verification system allows administrators to review and approve/reject provider applications. This ensures only qualified providers can offer classes on the platform.

### Setup Admin Access

1. **Create Admin User**
   ```bash
   node scripts/createAdmin.js
   ```
   
   This creates an admin user with:
   - Email: `info@yugiapp.ai`
   - Password: `admin123456`
   - **Important**: Change the password after first login!

2. **Access Admin Interface**
   - URL: `http://localhost:5000/admin`
   - Login with admin credentials
   - Review pending provider applications

### Provider Verification Flow

1. **Provider Signs Up**
   - Provider creates account with business details
   - Uploads qualifications and DBS certificate
   - Application status: `pending`

2. **Admin Review**
   - Admin logs into admin interface
   - Views pending applications
   - Reviews provider details and documents
   - Approves or rejects with reason

3. **Provider Notification**
   - Email sent to provider with decision
   - App notification updates status
   - Approved providers can create classes

### Admin API Endpoints

#### Get Pending Providers
```http
GET /api/admin/providers/pending?page=1&limit=10&status=pending
Authorization: Bearer <admin_token>
```

#### Get Provider Details
```http
GET /api/admin/providers/:id
Authorization: Bearer <admin_token>
```

#### Approve/Reject Provider
```http
PUT /api/admin/providers/:id/verify
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "action": "approve"
}

// OR for rejection:
{
  "action": "reject",
  "reason": "DBS certificate is expired. Please provide updated certificate."
}
```

#### Admin Dashboard Stats
```http
GET /api/admin/dashboard
Authorization: Bearer <admin_token>
```

### Verification Statuses

- **`pending`**: Initial status when provider signs up
- **`underReview`**: Admin is reviewing the application
- **`approved`**: Provider verified and can create classes
- **`rejected`**: Application rejected with reason

### Admin Interface Features

- **Dashboard Overview**: Statistics and recent applications
- **Provider List**: View all pending applications
- **Detailed Review**: View provider details and documents
- **Quick Actions**: Approve/reject with one click
- **Reason Tracking**: Record rejection reasons
- **Email Notifications**: Automatic emails to providers

### Security Considerations

- Admin routes require admin user type
- JWT authentication required
- Rate limiting on admin endpoints
- Audit trail for verification actions
- Secure document storage for qualifications

## 🔐 Security Features

- **JWT Authentication**: Secure token-based authentication
- **Password Hashing**: bcrypt for password security
- **Input Validation**: Express-validator for request validation
- **Rate Limiting**: API rate limiting to prevent abuse
- **CORS**: Cross-origin resource sharing configuration
- **Helmet**: Security headers middleware

## 💳 Payment Integration

### Stripe Setup
1. Create a Stripe account
2. Get your API keys from the dashboard
3. Set up webhook endpoints
4. Configure the webhook secret

### Payment Flow
1. Create booking (pending payment)
2. Create payment intent
3. Process payment on frontend
4. Confirm payment via webhook
5. Update booking status

## 📊 Analytics

### Provider Analytics
- Total bookings and revenue
- Class performance metrics
- Booking status breakdown
- Time-based analytics

## 🚀 Deployment

### Environment Variables
```env
NODE_ENV=production
PORT=5000
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/yugi
JWT_SECRET=your-production-jwt-secret
STRIPE_SECRET_KEY=sk_live_your_stripe_live_key
STRIPE_WEBHOOK_SECRET=whsec_your_live_webhook_secret
```

### Production Commands
```bash
npm install --production
npm start
```

## 🧪 Testing

```bash
# Run tests
npm test

# Run tests with coverage
npm run test:coverage
```

## 📝 API Response Format

All API responses follow this format:
```json
{
  "success": true,
  "message": "Operation completed successfully",
  "data": {
    // Response data
  },
  "pagination": {
    // Pagination info (if applicable)
  }
}
```

## 🔍 Error Handling

Errors follow this format:
```json
{
  "success": false,
  "message": "Error description",
  "errors": [
    // Validation errors (if applicable)
  ]
}
```

## 📞 Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the API documentation

## 📄 License

This project is licensed under the MIT License. 