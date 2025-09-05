const mongoose = require('mongoose');

const classSchema = new mongoose.Schema({
  // Basic Info
  name: {
    type: String,
    required: true,
    trim: true
  },
  description: {
    type: String,
    required: true
  },
  category: {
    type: String,
    enum: ['baby', 'toddler', 'wellness'],
    required: true
  },
  
  // Provider Info
  provider: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  
  // Media
  images: [{
    type: String,
    default: []
  }],
  
  // Pricing & Capacity
  price: {
    type: Number,
    required: true,
    min: 0
  },
  adultsPaySame: {
    type: Boolean,
    default: true
  },
  adultPrice: {
    type: Number,
    default: 0,
    min: 0
  },
  adultsFree: {
    type: Boolean,
    default: false
  },
  individualChildSpots: {
    type: String,
    enum: ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15'],
    default: '1'
  },
  siblingPairs: {
    type: String,
    enum: ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15'],
    default: '0'
  },
  siblingPrice: {
    type: Number,
    default: 0,
    min: 0
  },
  maxCapacity: {
    type: Number,
    required: true,
    min: 1
  },
  currentBookings: {
    type: Number,
    default: 0
  },
  
  // Schedule
  recurringDays: [{
    type: String,
    enum: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
  }],
  timeSlots: [{
    startTime: {
      type: String,
      required: true
    },
    endTime: {
      type: String,
      required: true
    }
  }],
  duration: {
    type: Number, // in minutes
    required: true
  },
  
  // Location
  location: {
    name: String,
    address: {
      street: String,
      city: String,
      postcode: String,
      country: String,
      formatted: String
    },
    coordinates: {
      latitude: Number,
      longitude: Number
    }
  },
  
  // Class Details
  ageRange: {
    type: String,
    required: true
  },
  whatToBring: {
    type: String,
    default: ''
  },
  specialRequirements: {
    type: String,
    default: ''
  },
  accessibilityNotes: {
    type: String,
    default: ''
  },
  
  // Status & Reviews
  isActive: {
    type: Boolean,
    default: true
  },
  isPublished: {
    type: Boolean,
    default: false
  },
  averageRating: {
    type: Number,
    default: 0,
    min: 0,
    max: 5
  },
  totalReviews: {
    type: Number,
    default: 0
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

// Virtual for available spots
classSchema.virtual('availableSpots').get(function() {
  return this.maxCapacity - this.currentBookings;
});

// Virtual for isFull
classSchema.virtual('isFull').get(function() {
  return this.currentBookings >= this.maxCapacity;
});

// Index for search
classSchema.index({ name: 'text', description: 'text' });
classSchema.index({ category: 1, isActive: 1, isPublished: 1 });
classSchema.index({ provider: 1, isActive: 1 });

module.exports = mongoose.model('Class', classSchema); 