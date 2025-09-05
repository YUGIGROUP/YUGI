const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  // Basic Information
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true
  },
  fullName: {
    type: String,
    required: true,
    trim: true
  },
  phoneNumber: {
    type: String,
    required: true,
    trim: true
  },
  profileImage: {
    type: String,
    default: null
  },
  
  // Account Type
  userType: {
    type: String,
    enum: ['parent', 'provider'],
    required: true
  },
  
  // Provider-specific fields
  businessInfo: {
    businessName: String,
    description: String,
    address: String,
    qualifications: String,
    verificationStatus: {
      type: String,
      enum: ['pending', 'approved', 'rejected'],
      default: 'pending'
    }
  },
  
  // Parent-specific fields
  children: [{
    _id: {
      type: mongoose.Schema.Types.ObjectId,
      auto: true
    },
    name: String,
    age: Number,
    dateOfBirth: Date
  }],
  
  // Authentication
  firebaseUid: {
    type: String,
    unique: true,
    sparse: true,
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

// Index for faster queries
userSchema.index({ email: 1 });
userSchema.index({ userType: 1 });
userSchema.index({ firebaseUid: 1 });

// Virtual for user display name
userSchema.virtual('displayName').get(function() {
  return this.fullName || this.email;
});

// Method to get user profile (without sensitive data)
userSchema.methods.toProfileJSON = function() {
  return {
    _id: this._id.toString(),
    email: this.email,
    fullName: this.fullName,
    phoneNumber: this.phoneNumber,
    profileImage: this.profileImage,
    userType: this.userType,
    businessName: this.businessInfo?.businessName || null,
    businessAddress: this.businessInfo?.address || null,
    qualifications: this.businessInfo?.qualifications || null,
    dbsCertificate: null, // Not implemented yet
    verificationStatus: this.businessInfo?.verificationStatus || 'pending',
    children: this.children && this.children.length > 0 ? this.children.map(child => ({
      _id: child._id?.toString(),
      name: child.name,
      age: child.age,
      dateOfBirth: child.dateOfBirth
    })) : null,
    isActive: true,
    isEmailVerified: true,
    createdAt: this.createdAt,
    updatedAt: this.updatedAt
  };
};

module.exports = mongoose.model('User', userSchema);
