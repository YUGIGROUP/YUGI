// Shared in-memory storage for development when MongoDB is not available
const inMemoryUsers = new Map();

// Helper function to check if we should use in-memory storage
const useInMemoryStorage = () => {
  return process.env.NODE_ENV === 'development' && !process.env.MONGODB_URI;
};

// Create test users for development
const createTestUsers = () => {
  // Test user 1: Tessa (parent)
  const tessaUser = {
    _id: 'test-user-id-123',
    email: 'tessa@test.com',
    fullName: 'Tessa Test',
    userType: 'parent',
    phoneNumber: '+44 123 456 7890',
    profileImage: null,
    businessName: null,
    businessAddress: null,
    qualifications: null,
    dbsCertificate: null,
    verificationStatus: 'pending',
    isActive: true,
    isEmailVerified: false,
    children: [],
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    location: null
  };
  inMemoryUsers.set('tessa@test.com', tessaUser);
  
  // Test user 2: Macy (provider) - matches the iOS app
  const macyUser = {
    _id: 'test-user-id-456',
    email: 'macy@test.com',
    fullName: 'Macy Provider',
    userType: 'provider',
    phoneNumber: '+44 987 654 3210',
    profileImage: null,
    businessName: 'Macy\'s Sensory Studio',
    businessAddress: '123 Sensory Street, London',
    qualifications: 'Certified Sensory Therapist',
    dbsCertificate: 'DBS123456',
    verificationStatus: 'verified',
    isActive: true,
    isEmailVerified: true,
    children: [],
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    location: null
  };
  inMemoryUsers.set('macy@test.com', macyUser);
  
  console.log('✅ Created test users: tessa@test.com (parent), macy@test.com (provider)');
};

// Initialize test users if using in-memory storage
if (useInMemoryStorage()) {
  createTestUsers();
}

module.exports = {
  inMemoryUsers,
  useInMemoryStorage,
  createTestUsers
};
