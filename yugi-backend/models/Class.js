const mongoose = require('mongoose');

const classSchema = new mongoose.Schema({
  // Basic Information
  title: {
    type: String,
    required: true,
    trim: true
  },
  description: {
    type: String,
    required: true,
    trim: true
  },
  category: {
    type: String,
    enum: ['baby', 'toddler', 'wellness'],
    required: true
  },
  
  // Provider Information
  provider: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  
  // Pricing
  price: {
    type: Number,
    required: true,
    min: 0
  },
  siblingPrice: {
    type: Number,
    min: 0,
    default: null
  },
  
  // Adult Pricing
  adultsPaySame: {
    type: Boolean,
    default: false
  },
  adultPrice: {
    type: Number,
    min: 0,
    default: null
  },
  adultsFree: {
    type: Boolean,
    default: true
  },
  
  // Capacity & Tickets
  individualChildSpots: {
    type: String,
    enum: ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10'],
    required: true
  },
  siblingPairs: {
    type: String,
    enum: ['0', '1', '2', '3', '4', '5'],
    required: true
  },
  allowSiblings: {
    type: Boolean,
    default: false
  },
  
  // Schedule
  startDate: {
    type: Date,
    required: true
  },
  endDate: {
    type: Date,
    required: true
  },
  startTime: {
    type: String,
    required: true
  },
  endTime: {
    type: String,
    required: true
  },
  daysOfWeek: [{
    type: String,
    enum: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
  }],
  
  // Location
  venueName: {
    type: String,
    required: true,
    trim: true
  },
  venueAddress: {
    type: String,
    required: true,
    trim: true
  },
  latitude: {
    type: Number,
    required: true
  },
  longitude: {
    type: Number,
    required: true
  },
  
  // Media
  classImage: {
    type: String,
    default: null
  },
  
  // Status
  status: {
    type: String,
    enum: ['draft', 'published', 'cancelled', 'completed'],
    default: 'draft'
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

// Indexes for faster queries
classSchema.index({ provider: 1 });
classSchema.index({ category: 1 });
classSchema.index({ status: 1 });
classSchema.index({ startDate: 1 });
classSchema.index({ 'venueAddress': 'text', 'title': 'text', 'description': 'text' });

// Virtual for total child spots
classSchema.virtual('totalChildSpots').get(function() {
  const individual = parseInt(this.individualChildSpots) || 0;
  const siblings = parseInt(this.siblingPairs) || 0;
  return individual + siblings;
});

// Virtual for max capacity
classSchema.virtual('maxCapacity').get(function() {
  const individual = parseInt(this.individualChildSpots) || 0;
  const siblings = parseInt(this.siblingPairs) || 0;
  return individual + (siblings * 2); // Each sibling pair = 2 children
});

// Method to check if class is available
classSchema.methods.isAvailable = function() {
  return this.status === 'published' && new Date() < this.endDate;
};

// Method to get class summary
classSchema.methods.toSummaryJSON = function() {
  return {
    id: this._id,
    title: this.title,
    description: this.description,
    category: this.category,
    price: this.price,
    siblingPrice: this.siblingPrice,
    venueName: this.venueName,
    venueAddress: this.venueAddress,
    startDate: this.startDate,
    endDate: this.endDate,
    startTime: this.startTime,
    endTime: this.endTime,
    daysOfWeek: this.daysOfWeek,
    totalChildSpots: this.totalChildSpots,
    maxCapacity: this.maxCapacity,
    classImage: this.classImage,
    status: this.status,
    createdAt: this.createdAt
  };
};

module.exports = mongoose.model('Class', classSchema);
