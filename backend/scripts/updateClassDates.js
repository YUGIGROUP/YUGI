const mongoose = require('mongoose');
require('dotenv').config();

// Import the Class model
const Class = require('../src/models/Class');

// Connect to MongoDB
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/yugi');

async function updateClassDates() {
  try {
    console.log('🔄 Connecting to database...');
    
    // Wait for connection
    await new Promise((resolve) => {
      if (mongoose.connection.readyState === 1) {
        resolve();
      } else {
        mongoose.connection.once('open', resolve);
      }
    });

    console.log('✅ Connected to MongoDB');

    // Set the target date: January 10th, 2026
    const targetDate = new Date('2026-01-10T00:00:00.000Z');
    targetDate.setHours(0, 0, 0, 0);

    console.log(`📅 Updating specific classes to have classDates set to: ${targetDate.toISOString().split('T')[0]}`);

    // Update only the specific classes by name
    const classNamesToUpdate = [
      'Restore & Align Postnatal Pilates',
      'Little Glow Sensory'
    ];

    console.log(`🎯 Targeting classes: ${classNamesToUpdate.join(', ')}`);

    // Update the specific classes
    const result = await Class.updateMany(
      { name: { $in: classNamesToUpdate } },
      {
        $set: {
          classDates: [targetDate]
        }
      }
    );

    console.log(`✅ Successfully updated ${result.modifiedCount} classes`);
    console.log(`📊 Total classes matched: ${result.matchedCount}`);

    // Verify the update by fetching the updated classes
    const updatedClasses = await Class.find({ name: { $in: classNamesToUpdate } }).select('name classDates');
    console.log('\n📋 Updated classes:');
    updatedClasses.forEach((classItem) => {
      console.log(`  - ${classItem.name}: ${classItem.classDates?.map(d => d.toISOString().split('T')[0]).join(', ') || 'No dates'}`);
    });

    process.exit(0);
  } catch (error) {
    console.error('❌ Error updating class dates:', error);
    process.exit(1);
  }
}

// Run the update
updateClassDates();

