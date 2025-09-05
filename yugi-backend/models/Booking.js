const mongoose = require('mongoose');

const bookingSchema = new mongoose.Schema({
  // Booking Information
  bookingId: {
    type: String,
    required: true,
    unique: true
  },
  
  // Participants
  parent: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  provider: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  class: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Class',
    required: true
  },
  
  // Children Information
  children: [{
    name: String,
    age: Number,
    dateOfBirth: Date
  }],
  
  // Booking Details
  bookingDate: {
    type: Date,
    required: true
  },
  numberOfChildren: {
    type: Number,
    required: true,
    min: 1
  },
  numberOfAdults: {
    type: Number,
    default: 0,
    min: 0
  },
  
  // Pricing
  totalPrice: {
    type: Number,
    required: true,
    min: 0
  },
  childPrice: {
    type: Number,
    required: true,
    min: 0
  },
  adultPrice: {
    type: Number,
    default: 0,
    min: 0
  },
  
  // Payment Information
  paymentStatus: {
    type: String,
    enum: ['pending', 'paid', 'failed', 'refunded'],
    default: 'pending'
  },
  paymentMethod: {
    type: String,
    default: null
  },
  stripePaymentIntentId: {
    type: String,
    default: null
  },
  
  // Booking Status
  status: {
    type: String,
    enum: ['confirmed', 'cancelled', 'completed', 'no-show'],
    default: 'confirmed'
  },
  
  // Cancellation
  cancelledAt: {
    type: Date,
    default: null
  },
  cancellationReason: {
    type: String,
    default: null
  },
  
  // Notes
  parentNotes: {
    type: String,
    default: null
  },
  providerNotes: {
    type: String,
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

// Indexes for faster queries
bookingSchema.index({ parent: 1 });
bookingSchema.index({ provider: 1 });
bookingSchema.index({ class: 1 });
bookingSchema.index({ bookingDate: 1 });
bookingSchema.index({ status: 1 });
bookingSchema.index({ paymentStatus: 1 });
bookingSchema.index({ bookingId: 1 });

// Pre-save middleware to generate booking ID
bookingSchema.pre('save', function(next) {
  if (!this.bookingId) {
    this.bookingId = generateBookingId();
  }
  next();
});

// Method to generate booking ID
function generateBookingId() {
  const timestamp = Date.now().toString(36);
  const random = Math.random().toString(36).substr(2, 5);
  return `YUGI-${timestamp}-${random}`.toUpperCase();
}

// Method to check if booking is active
bookingSchema.methods.isActive = function() {
  return this.status === 'confirmed' && this.paymentStatus === 'paid';
};

// Method to check if booking can be cancelled
bookingSchema.methods.canBeCancelled = function() {
  const now = new Date();
  const bookingTime = new Date(this.bookingDate);
  const hoursUntilBooking = (bookingTime - now) / (1000 * 60 * 60);
  
  return this.status === 'confirmed' && hoursUntilBooking > 24;
};

// Method to get booking summary
bookingSchema.methods.toSummaryJSON = function() {
  return {
    id: this._id,
    bookingId: this.bookingId,
    parent: this.parent,
    provider: this.provider,
    class: this.class,
    children: this.children,
    bookingDate: this.bookingDate,
    numberOfChildren: this.numberOfChildren,
    numberOfAdults: this.numberOfAdults,
    totalPrice: this.totalPrice,
    status: this.status,
    paymentStatus: this.paymentStatus,
    createdAt: this.createdAt
  };
};

module.exports = mongoose.model('Booking', bookingSchema);
