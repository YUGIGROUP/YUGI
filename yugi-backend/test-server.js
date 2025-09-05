const express = require('express');
const cors = require('cors');

const app = express();

// Simple in-memory user storage for testing
const users = new Map();
const tokens = new Map(); // token -> userId mapping

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Basic route
app.get('/', (req, res) => {
  res.json({ 
    message: '🚀 YUGI Backend API is running!',
    version: '1.0.0',
    status: 'active',
    timestamp: new Date().toISOString()
  });
});

// Health check route
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy',
    timestamp: new Date().toISOString(),
    database: 'not connected (test mode)'
  });
});

// Test API endpoints
app.get('/api/test', (req, res) => {
  res.json({
    message: 'API is working!',
    endpoints: {
      users: '/api/users',
      classes: '/api/classes',
      bookings: '/api/bookings'
    }
  });
});

// Authentication endpoints
app.post('/api/auth/login', (req, res) => {
  console.log('🔐 Login attempt:', req.body);
  
  const { email, password, firebaseUid } = req.body;
  
  // Mock authentication - accept any valid email/password or Firebase UID
  if ((email && password) || (email && firebaseUid)) {
    // Check if user exists, if not create a default one
    let userData;
    if (users.has(email)) {
      userData = users.get(email);
    } else {
      // Create default user data based on email
      userData = {
        id: firebaseUid || 'user-id-' + Date.now(),
        email: email,
        fullName: email === 'margot@test.com' ? 'Margot Test' : 'Test User',
        userType: 'parent',
        phoneNumber: '+1234567890',
        profileImage: null,
        businessName: null,
        businessAddress: null,
        qualifications: null,
        dbsCertificate: null,
        verificationStatus: 'verified',
        children: [],
        isActive: true,
        isEmailVerified: true,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      };
      users.set(email, userData);
    }
    
    const token = 'mock-jwt-token-' + Date.now();
    tokens.set(token, userData.id);
    
    res.json({
      token: token,
      user: userData
    });
  } else {
    res.status(400).json({
      success: false,
      message: 'Email and password (or Firebase UID) are required'
    });
  }
});

app.post('/api/auth/signup', (req, res) => {
  console.log('🔐 Signup attempt:', req.body);
  
  const { email, password, fullName, userType, firebaseUid } = req.body;
  
  // Mock signup - accept any valid data with or without Firebase UID
  if (email && fullName && userType && (password || firebaseUid)) {
    // Create user data
    const userData = {
      id: firebaseUid || 'user-id-' + Date.now(),
      email: email,
      fullName: fullName,
      userType: userType,
      phoneNumber: req.body.phoneNumber || '+1234567890',
      profileImage: null,
      businessName: req.body.businessName || null,
      businessAddress: req.body.businessAddress || null,
      qualifications: null,
      dbsCertificate: null,
      verificationStatus: 'verified',
      children: [],
      isActive: true,
      isEmailVerified: true,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    
    // Store user data
    users.set(email, userData);
    
    const token = 'mock-jwt-token-' + Date.now();
    tokens.set(token, userData.id);
    
    res.json({
      token: token,
      user: userData
    });
  } else {
    res.status(400).json({
      success: false,
      message: 'Email, fullName, userType, and password (or Firebase UID) are required'
    });
  }
});

app.get('/api/auth/me', (req, res) => {
  console.log('🔐 Get current user request');
  
  // Get the authorization header to extract user info
  const authHeader = req.headers.authorization;
  console.log('🔐 Auth header:', authHeader);
  
  // Extract token from Authorization header
  let token = null;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    token = authHeader.substring(7); // Remove 'Bearer ' prefix
  }
  
  // Find user by token
  let userData = null;
  if (token && tokens.has(token)) {
    const userId = tokens.get(token);
    // Find user by ID
    for (let [email, user] of users) {
      if (user.id === userId) {
        userData = user;
        break;
      }
    }
  }
  
  // If no user found, return default data
  if (!userData) {
    userData = {
      id: 'user-id-' + Date.now(),
      email: 'margot@test.com',
      fullName: 'Margot Test',
      userType: 'parent',
      phoneNumber: '+1234567890',
      profileImage: null,
      businessName: null,
      businessAddress: null,
      qualifications: null,
      dbsCertificate: null,
      verificationStatus: 'verified',
      children: [],
      isActive: true,
      isEmailVerified: true,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
  }
  
  res.json({
    data: userData
  });
});

// Children endpoints
app.post('/api/users/children', (req, res) => {
  console.log('👶 Add child request:', req.body);
  
  // Get the authorization header to extract user info
  const authHeader = req.headers.authorization;
  console.log('👶 Auth header:', authHeader);
  
  // Extract token from Authorization header
  let token = null;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    token = authHeader.substring(7); // Remove 'Bearer ' prefix
  }
  
  // Find user by token
  let userData = null;
  if (token && tokens.has(token)) {
    const userId = tokens.get(token);
    // Find user by ID
    for (let [email, user] of users) {
      if (user.id === userId) {
        userData = user;
        break;
      }
    }
  }
  
  if (!userData) {
    return res.status(401).json({
      success: false,
      message: 'User not found'
    });
  }
  
  const { name, age, dateOfBirth } = req.body;
  
  if (!name || age === undefined) {
    return res.status(400).json({
      success: false,
      message: 'Name and age are required'
    });
  }
  
  // Create new child
  const newChild = {
    id: 'child-id-' + Date.now(),
    name: name,
    age: age,
    dateOfBirth: dateOfBirth || new Date().toISOString()
  };
  
  // Add child to user's children array
  if (!userData.children) {
    userData.children = [];
  }
  userData.children.push(newChild);
  
  // Update user in storage
  users.set(userData.email, userData);
  
  console.log('👶 Child added successfully:', newChild);
  console.log('👶 User now has', userData.children.length, 'children');
  
  res.json({
    data: userData.children
  });
});

app.put('/api/users/children/:childId', (req, res) => {
  console.log('👶 Edit child request:', req.params.childId, req.body);
  
  // Get the authorization header to extract user info
  const authHeader = req.headers.authorization;
  
  // Extract token from Authorization header
  let token = null;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    token = authHeader.substring(7);
  }
  
  // Find user by token
  let userData = null;
  if (token && tokens.has(token)) {
    const userId = tokens.get(token);
    for (let [email, user] of users) {
      if (user.id === userId) {
        userData = user;
        break;
      }
    }
  }
  
  if (!userData) {
    return res.status(401).json({
      success: false,
      message: 'User not found'
    });
  }
  
  const childId = req.params.childId;
  const { name, age, dateOfBirth } = req.body;
  
  // Find and update child
  const childIndex = userData.children.findIndex(child => child.id === childId);
  if (childIndex === -1) {
    return res.status(404).json({
      success: false,
      message: 'Child not found'
    });
  }
  
  userData.children[childIndex] = {
    ...userData.children[childIndex],
    name: name || userData.children[childIndex].name,
    age: age !== undefined ? age : userData.children[childIndex].age,
    dateOfBirth: dateOfBirth || userData.children[childIndex].dateOfBirth
  };
  
  // Update user in storage
  users.set(userData.email, userData);
  
  res.json({
    data: userData.children
  });
});

app.delete('/api/users/children/:childId', (req, res) => {
  console.log('👶 Delete child request:', req.params.childId);
  
  // Get the authorization header to extract user info
  const authHeader = req.headers.authorization;
  
  // Extract token from Authorization header
  let token = null;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    token = authHeader.substring(7);
  }
  
  // Find user by token
  let userData = null;
  if (token && tokens.has(token)) {
    const userId = tokens.get(token);
    for (let [email, user] of users) {
      if (user.id === userId) {
        userData = user;
        break;
      }
    }
  }
  
  if (!userData) {
    return res.status(401).json({
      success: false,
      message: 'User not found'
    });
  }
  
  const childId = req.params.childId;
  
  // Find and remove child
  const childIndex = userData.children.findIndex(child => child.id === childId);
  if (childIndex === -1) {
    return res.status(404).json({
      success: false,
      message: 'Child not found'
    });
  }
  
  userData.children.splice(childIndex, 1);
  
  // Update user in storage
  users.set(userData.email, userData);
  
  res.json({
    success: true,
    message: 'Child deleted successfully'
  });
});

// Profile update endpoint
app.put('/api/users/profile', (req, res) => {
  console.log('👤 Update profile request:', req.body);
  
  // Get the authorization header to extract user info
  const authHeader = req.headers.authorization;
  console.log('🔐 Auth header:', authHeader);
  
  // Extract token from Authorization header
  let token = null;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    token = authHeader.substring(7);
  }
  
  // Find user by token
  let userData = null;
  if (token && tokens.has(token)) {
    const userId = tokens.get(token);
    for (let [email, user] of users) {
      if (user.id === userId) {
        userData = user;
        break;
      }
    }
  }
  
  if (!userData) {
    return res.status(401).json({
      success: false,
      message: 'User not found'
    });
  }
  
  const { fullName, phoneNumber, email: newEmail } = req.body;
  
  // Update user data
  if (fullName) {
    userData.fullName = fullName;
  }
  if (phoneNumber) {
    userData.phoneNumber = phoneNumber;
  }
  if (newEmail && newEmail !== userData.email) {
    // Update the key in the Map if email is changing
    users.delete(userData.email);
    userData.email = newEmail;
    users.set(newEmail, userData);
  }
  
  // Update timestamp
  userData.updatedAt = new Date().toISOString();
  
  // Save updated user data
  users.set(userData.email, userData);
  
  console.log('👤 Profile updated successfully for:', userData.fullName);
  
  res.json({
    success: true,
    message: 'Profile updated successfully',
    data: userData
  });
});

// Location update endpoint
app.post('/api/users/update-location', (req, res) => {
  console.log('📍 Update location request:', req.body);
  
  // Get the authorization header to extract user info
  const authHeader = req.headers.authorization;
  console.log('🔐 Auth header:', authHeader);
  
  // Extract token from Authorization header
  let token = null;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    token = authHeader.substring(7);
  }
  
  // Find user by token
  let userData = null;
  if (token && tokens.has(token)) {
    const userId = tokens.get(token);
    for (let [email, user] of users) {
      if (user.id === userId) {
        userData = user;
        break;
      }
    }
  }
  
  if (!userData) {
    return res.status(401).json({
      success: false,
      message: 'User not found'
    });
  }
  
  const { lat, lng } = req.body;
  
  // Validate coordinates
  if (typeof lat !== 'number' || typeof lng !== 'number') {
    return res.status(400).json({
      success: false,
      message: 'Invalid coordinates. lat and lng must be numbers.'
    });
  }
  
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    return res.status(400).json({
      success: false,
      message: 'Invalid coordinates. lat must be between -90 and 90, lng must be between -180 and 180.'
    });
  }
  
  // Update user location
  userData.location = {
    lat: lat,
    lng: lng,
    updatedAt: new Date().toISOString()
  };
  
  // Update timestamp
  userData.updatedAt = new Date().toISOString();
  
  // Save updated user data
  users.set(userData.email, userData);
  
  console.log('📍 Location updated successfully for:', userData.fullName, 'at', lat, lng);
  
  res.json({
    success: true,
    message: 'Location updated successfully',
    location: userData.location
  });
});

// Classes by location endpoint
app.get('/api/classes', (req, res) => {
  console.log('🏫 Classes request with query params:', req.query);
  
  const { lat, lng } = req.query;
  
  // Default to London coordinates if no location provided
  const userLat = lat ? parseFloat(lat) : 51.5072;
  const userLng = lng ? parseFloat(lng) : -0.1276;
  
  console.log('📍 Using coordinates:', userLat, userLng);
  
  // Mock classes data (in a real app, this would come from a database)
  const mockClasses = [
    {
      id: 'class-1',
      name: 'Baby Yoga',
      category: 'Baby',
      description: 'Gentle yoga for babies and parents',
      location: {
        lat: 51.5072,
        lng: -0.1276,
        address: 'Central London'
      },
      distance: calculateDistance(userLat, userLng, 51.5072, -0.1276),
      price: 15.00,
      duration: 45,
      instructor: 'Sarah Johnson',
      maxParticipants: 8,
      currentParticipants: 5,
      schedule: [
        { day: 'Monday', time: '10:00 AM' },
        { day: 'Wednesday', time: '10:00 AM' }
      ]
    },
    {
      id: 'class-2',
      name: 'Toddler Music',
      category: 'Toddler',
      description: 'Interactive music and movement for toddlers',
      location: {
        lat: 51.5100,
        lng: -0.1300,
        address: 'Westminster, London'
      },
      distance: calculateDistance(userLat, userLng, 51.5100, -0.1300),
      price: 18.00,
      duration: 30,
      instructor: 'Mike Chen',
      maxParticipants: 12,
      currentParticipants: 8,
      schedule: [
        { day: 'Tuesday', time: '9:30 AM' },
        { day: 'Thursday', time: '9:30 AM' }
      ]
    },
    {
      id: 'class-3',
      name: 'Parent Wellness',
      category: 'Wellness',
      description: 'Mindfulness and relaxation for parents',
      location: {
        lat: 51.5050,
        lng: -0.1250,
        address: 'South Bank, London'
      },
      distance: calculateDistance(userLat, userLng, 51.5050, -0.1250),
      price: 25.00,
      duration: 60,
      instructor: 'Emma Davis',
      maxParticipants: 15,
      currentParticipants: 12,
      schedule: [
        { day: 'Friday', time: '7:00 PM' },
        { day: 'Sunday', time: '10:00 AM' }
      ]
    }
  ];
  
  // Sort by distance
  mockClasses.sort((a, b) => a.distance - b.distance);
  
  res.json({
    success: true,
    message: 'Classes retrieved successfully',
    data: {
      classes: mockClasses,
      userLocation: { lat: userLat, lng: userLng },
      totalClasses: mockClasses.count
    }
  });
});

// Helper function to calculate distance between two coordinates (Haversine formula)
function calculateDistance(lat1, lng1, lat2, lng2) {
  const R = 6371; // Earth's radius in kilometers
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLng/2) * Math.sin(dLng/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  const distance = R * c; // Distance in kilometers
  
  return Math.round(distance * 100) / 100; // Round to 2 decimal places
}

const PORT = process.env.PORT || 3000;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 YUGI Backend test server running on port ${PORT}`);
  console.log(`📱 Environment: development`);
  console.log(`🔗 Health check: http://localhost:${PORT}/health`);
  console.log(`🔗 API test: http://localhost:${PORT}/api/test`);
  console.log(`🌐 Network access: http://192.168.1.72:${PORT}/api/test`);
});
