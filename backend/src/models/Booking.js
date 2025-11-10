const mongoose = require('mongoose');

const bookingSchema = new mongoose.Schema({
  // Booking Info
  bookingNumber: {
    type: String,
    unique: true,
    required: true
  },
  
  // Participants
  parent: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  children: [{
    name: String,
    age: Number
  }],
  
  // Class Info
  class: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Class',
    required: true
  },
  
  // Session Details
  sessionDate: {
    type: Date,
    required: true
  },
  sessionTime: {
    type: String,
    required: true
  },
  
  // Pricing
  basePrice: {
    type: Number,
    required: true
  },
  serviceFee: {
    type: Number,
    default: 1.99
  },
  totalAmount: {
    type: Number,
    required: true
  },
  
  // Payment Info
  paymentStatus: {
    type: String,
    enum: ['pending', 'paid', 'failed', 'refunded', 'held'],
    default: 'pending'
  },
  stripePaymentIntentId: {
    type: String
  },
  stripeChargeId: {
    type: String
  },
  
  // 3-Day Holding Period
  paymentDate: {
    type: Date
  },
  classCompletedAt: {
    type: Date
  },
  fundsReleaseDate: {
    type: Date
  },
  fundsReleased: {
    type: Boolean,
    default: false
  },
  fundsReleasedAt: {
    type: Date
  },
  
  // Booking Status
  status: {
    type: String,
    enum: ['confirmed', 'pending', 'cancelled', 'completed'],
    default: 'pending'
  },
  
  // Cancellation
  cancelledAt: {
    type: Date
  },
  cancellationReason: {
    type: String
  },
  refundAmount: {
    type: Number,
    default: 0
  },
  
  // Notes
  specialRequests: {
    type: String
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

// Generate booking number before saving
bookingSchema.pre('save', async function(next) {
  // Only generate if bookingNumber doesn't exist and this is a new document
  if (this.isNew && !this.bookingNumber) {
    try {
      const date = new Date();
      const year = date.getFullYear().toString().slice(-2);
      const month = (date.getMonth() + 1).toString().padStart(2, '0');
      const day = date.getDate().toString().padStart(2, '0');
      
      // Get count of bookings for today (use a simpler query that doesn't rely on createdAt)
      let count = 0;
      try {
        const todayStart = new Date(date.getFullYear(), date.getMonth(), date.getDate());
        const todayEnd = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1);
        
        count = await this.constructor.countDocuments({
          bookingNumber: { $regex: `^YUGI${year}${month}${day}` }
        });
      } catch (countError) {
        console.error('Error counting bookings (using fallback):', countError);
        // Fallback: use timestamp-based sequence if count fails
        count = Math.floor(Date.now() % 1000);
      }
      
      const sequence = (count + 1).toString().padStart(3, '0');
      this.bookingNumber = `YUGI${year}${month}${day}${sequence}`;
      
      console.log(`✅ Generated booking number: ${this.bookingNumber}`);
      next();
    } catch (error) {
      console.error('Error generating booking number:', error);
      // Fallback: generate a timestamp-based booking number
      const timestamp = Date.now().toString().slice(-6);
      this.bookingNumber = `YUGI${timestamp}`;
      console.log(`⚠️ Using fallback booking number: ${this.bookingNumber}`);
      next();
    }
  } else {
    next();
  }
});

// Indexes
bookingSchema.index({ parent: 1, createdAt: -1 });
bookingSchema.index({ class: 1, sessionDate: 1 });
bookingSchema.index({ bookingNumber: 1 });
bookingSchema.index({ paymentStatus: 1, status: 1 });

module.exports = mongoose.model('Booking', bookingSchema); 