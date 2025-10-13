const mongoose = require('mongoose');

// Category normalization function
const normalizeCategory = (category) => {
  if (!category) return category;
  return category.charAt(0).toUpperCase() + category.slice(1).toLowerCase();
};

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
    enum: ['baby', 'toddler', 'wellness', 'Baby', 'Toddler', 'Wellness'],
    required: true,
    set: normalizeCategory // Normalize to capitalized format when saving
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
    type: Number,
    default: 0,
    min: 0
  },
  siblingPairs: {
    type: Number,
    default: 0,
    min: 0
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
  
  // Location - Updated to match iOS expectations
  location: {
    name: {
      type: String,
      default: ''
    },
    address: {
      street: {
        type: String,
        default: ''
      },
      city: {
        type: String,
        default: ''
      },
      state: {
        type: String,
        default: ''
      },
      postalCode: {
        type: String,
        default: ''
      },
      country: {
        type: String,
        default: 'United Kingdom'
      },
      formatted: {
        type: String,
        default: ''
      }
    },
    coordinates: {
      latitude: {
        type: Number,
        default: 0
      },
      longitude: {
        type: Number,
        default: 0
      }
    },
    accessibilityNotes: {
      type: String,
      default: ''
    },
    parkingInfo: {
      type: String,
      default: ''
    },
    babyChangingFacilities: {
      type: String,
      default: ''
    }
  },
  
  // Class Details
  ageRange: {
    type: String,
    default: 'All ages'
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