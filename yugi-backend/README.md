# 🚀 YUGI Backend API

Backend API for YUGI - Children's Activity Booking Platform

## 📋 Overview

YUGI is a platform that connects parents with activity providers for children's classes and activities. This backend API handles user authentication, class management, bookings, and payments.

## 🏗️ Architecture

- **Framework**: Node.js with Express.js
- **Database**: MongoDB (MongoDB Atlas)
- **Authentication**: Firebase Auth
- **Payment Processing**: Stripe (coming soon)
- **File Storage**: AWS S3 (future)

## 🚀 Quick Start

### Prerequisites

- Node.js (v18 or higher)
- npm or yarn
- MongoDB Atlas account
- Firebase project

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd yugi-backend
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Set up environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your actual values
   ```

4. **Start the development server**
   ```bash
   npm run dev
   ```

## 🔧 Environment Variables

Create a `.env` file in the root directory:

```env
# Server Configuration
PORT=3000
NODE_ENV=development

# MongoDB Configuration
MONGODB_URI=your_mongodb_connection_string

# Firebase Configuration
FIREBASE_API_KEY=your_firebase_api_key
FIREBASE_PROJECT_ID=your_firebase_project_id

# JWT Configuration
JWT_SECRET=your_jwt_secret_key

# Stripe Configuration (when ready)
STRIPE_PUBLISHABLE_KEY=your_stripe_publishable_key
STRIPE_SECRET_KEY=your_stripe_secret_key
```

## 📁 Project Structure

```
yugi-backend/
├── models/          # Database models
│   ├── User.js
│   ├── Class.js
│   └── Booking.js
├── routes/          # API routes
├── controllers/     # Route controllers
├── middleware/      # Custom middleware
├── config/          # Configuration files
├── server.js        # Main server file
├── package.json
└── README.md
```

## 🗄️ Database Models

### User Model
- **Parent accounts**: Can book classes, manage children
- **Provider accounts**: Can create classes, manage bookings
- **Authentication**: Firebase UID integration

### Class Model
- **Categories**: baby, toddler, wellness
- **Pricing**: Individual and sibling pricing
- **Capacity**: Individual spots and sibling pairs
- **Schedule**: Date, time, recurring days

### Booking Model
- **Participants**: Parent, provider, class, children
- **Pricing**: Total price breakdown
- **Status**: confirmed, cancelled, completed
- **Payment**: Stripe integration

## 🔌 API Endpoints

### Authentication
- `POST /api/auth/signup` - User registration
- `POST /api/auth/login` - User login
- `POST /api/auth/logout` - User logout

### Users
- `GET /api/users/profile` - Get user profile
- `PUT /api/users/profile` - Update user profile
- `GET /api/users/children` - Get user's children

### Classes
- `GET /api/classes` - Get all classes
- `POST /api/classes` - Create new class
- `GET /api/classes/:id` - Get specific class
- `PUT /api/classes/:id` - Update class
- `DELETE /api/classes/:id` - Delete class

### Bookings
- `GET /api/bookings` - Get user's bookings
- `POST /api/bookings` - Create new booking
- `GET /api/bookings/:id` - Get specific booking
- `PUT /api/bookings/:id` - Update booking
- `DELETE /api/bookings/:id` - Cancel booking

## 🛠️ Development

### Running in Development
```bash
npm run dev
```

### Running in Production
```bash
npm start
```

### Testing
```bash
npm test
```

## 🔒 Security Features

- **CORS**: Configured for cross-origin requests
- **Input Validation**: Request data validation
- **Authentication**: Firebase-based user authentication
- **Rate Limiting**: API rate limiting (future)
- **Data Sanitization**: Input sanitization

## 📊 Monitoring

- **Health Check**: `/health` endpoint
- **Error Logging**: Comprehensive error handling
- **Database Monitoring**: MongoDB connection status

## 🚀 Deployment

### AWS Deployment (Recommended)
1. Set up AWS EC2 instance
2. Configure environment variables
3. Use PM2 for process management
4. Set up Nginx reverse proxy

### Heroku Deployment
1. Connect GitHub repository
2. Set environment variables
3. Deploy automatically

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📝 License

This project is licensed under the ISC License.

## 🆘 Support

For support, email support@yugi-app.com or create an issue in the repository.

---

**Built with ❤️ for YUGI**
