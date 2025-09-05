const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  // Basic Info
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true
  },
  password: {
    type: String,
    required: true,
    minlength: 8
  },
  fullName: {
    type: String,
    required: true,
    trim: true
  },
  userType: {
    type: String,
    enum: ['parent', 'provider', 'other', 'admin'],
    required: true
  },
  
  // Profile Info
  profileImage: {
    type: String,
    default: null
  },
  phoneNumber: {
    type: String,
    trim: true
  },
  
  // Provider-specific fields
  businessName: {
    type: String,
    trim: true
  },
  businessAddress: {
    type: String,
    trim: true
  },
  qualifications: {
    type: String,
    default: null
  },
  dbsCertificate: {
    type: String,
    default: null
  },
  verificationStatus: {
    type: String,
    enum: ['pending', 'underReview', 'approved', 'rejected'],
    default: 'pending'
  },
  verificationDate: {
    type: Date,
    default: null
  },
  rejectionReason: {
    type: String,
    trim: true
  },
  
  // Parent-specific fields
  children: [{
    name: String,
    age: Number,
    dateOfBirth: Date
  }],
  
  // Account status
  isActive: {
    type: Boolean,
    default: true
  },
  isEmailVerified: {
    type: Boolean,
    default: false
  },
  
  // Password reset fields
  resetPasswordToken: {
    type: String,
    default: null
  },
  resetPasswordExpires: {
    type: Date,
    default: null
  },
  
  // Timestamps
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Hash password before saving
userSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  
  try {
    const salt = await bcrypt.genSalt(12);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (error) {
    next(error);
  }
});

// Compare password method
userSchema.methods.comparePassword = async function(candidatePassword) {
  return await bcrypt.compare(candidatePassword, this.password);
};

// Remove password from JSON response
userSchema.methods.toJSON = function() {
  const user = this.toObject();
  delete user.password;
  return user;
};

module.exports = mongoose.model('User', userSchema); 