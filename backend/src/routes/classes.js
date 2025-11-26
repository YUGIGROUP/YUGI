const express = require('express');
const { body, validationResult, query } = require('express-validator');
const Class = require('../models/Class');
const { protect, optionalAuth, requireProviderVerification } = require('../middleware/auth');
const venueDataService = require('../services/venueDataService');

const router = express.Router();

// Middleware to normalize category in responses
const normalizeCategoryInResponse = (req, res, next) => {
  const originalJson = res.json;
  res.json = function(data) {
    if (data && data.data) {
      if (Array.isArray(data.data)) {
        // Handle array of classes
        data.data = data.data.map(classItem => {
          if (classItem.category) {
            classItem.category = classItem.category.charAt(0).toUpperCase() + classItem.category.slice(1).toLowerCase();
          }
          return classItem;
        });
      } else if (data.data.category) {
        // Handle single class
        data.data.category = data.data.category.charAt(0).toUpperCase() + data.data.category.slice(1).toLowerCase();
      }
    }
    return originalJson.call(this, data);
  };
  next();
};

// Helper functions to provide default venue information
const getDefaultParkingInfo = (venueName) => {
  if (!venueName) return "Street parking available nearby";
  
  const name = venueName.toLowerCase();
  
  // Check for specific venue types
  if (name.includes('community') || name.includes('centre') || name.includes('center')) {
    return "Free parking available on-site";
  } else if (name.includes('library') || name.includes('museum')) {
    return "Limited parking - street parking recommended";
  } else if (name.includes('park') || name.includes('garden')) {
    return "Free parking available";
  } else if (name.includes('church') || name.includes('hall')) {
    return "On-site parking available";
  } else if (name.includes('cafe') || name.includes('restaurant')) {
    return "Street parking available nearby";
  } else {
    return "Street parking available nearby";
  }
};

const getDefaultChangingFacilities = (venueName) => {
  if (!venueName) return "Baby changing facilities available";
  
  const name = venueName.toLowerCase();
  
  // Check for specific venue types
  if (name.includes('community') || name.includes('centre') || name.includes('center')) {
    return "Baby changing facilities available";
  } else if (name.includes('library') || name.includes('museum')) {
    return "Baby changing facilities available";
  } else if (name.includes('church') || name.includes('hall')) {
    return "Baby changing facilities available";
  } else if (name.includes('cafe') || name.includes('restaurant')) {
    return "Baby changing facilities available";
  } else if (name.includes('park') || name.includes('garden')) {
    return "Portable changing facilities recommended";
  } else {
    return "Baby changing facilities available";
  }
};

// Helper function to correct common city name typos
const correctCityName = (city) => {
  if (!city) return city;
  
  const trimmedCity = city.trim();
  const cityLower = trimmedCity.toLowerCase();
  
  // Common typos and corrections
  const corrections = {
    'londo': 'London',
    'londn': 'London',
    'londom': 'London',
    'manchestr': 'Manchester',
    'manchest': 'Manchester',
    'birmngham': 'Birmingham',
    'birminghm': 'Birmingham',
    'edinbrugh': 'Edinburgh',
    'edinburg': 'Edinburgh',
    'glasgo': 'Glasgow',
    'glasgow': 'Glasgow' // Already correct, but included for consistency
  };
  
  if (corrections[cityLower]) {
    return corrections[cityLower];
  }
  
  return trimmedCity;
};

// Helper function to parse Google Places formatted_address to extract city
const parseCityFromFormattedAddress = (formattedAddress) => {
  if (!formattedAddress) return null;
  
  // Google Places formatted_address format: "240 The Broadway, London SW19 1SB, UK"
  // Try to extract city name (usually the second component before postal code)
  const parts = formattedAddress.split(',').map(p => p.trim());
  
  if (parts.length >= 2) {
    // City is usually the second part (index 1), before postal code
    const cityPart = parts[1];
    
    // UK postcode pattern: 1-2 letters + 1-2 digits + space + 1 digit + 2 letters
    // Examples: "SW19 1SB", "TW9 1EU", "M1 1AA"
    // Match city name (letters and spaces) before UK postcode pattern
    const ukPostcodePattern = /\s+[A-Z]{1,2}\d{1,2}\s+\d[A-Z]{2}/i;
    const postcodeIndex = cityPart.search(ukPostcodePattern);
    
    if (postcodeIndex > 0) {
      // Found a postcode, extract everything before it
      return cityPart.substring(0, postcodeIndex).trim();
    }
    
    // Fallback: try to match city name before any postal code pattern
    const fallbackMatch = cityPart.match(/^([A-Za-z]+(?:\s+[A-Za-z]+)*)/);
    if (fallbackMatch && fallbackMatch[1]) {
      return fallbackMatch[1].trim();
    }
    
    // Last resort: take first word
    return cityPart.split(/\s+/)[0];
  }
  
  console.log(`📍 parseCityFromFormattedAddress: no city found`);
  return null;
};

// Helper function to get the next occurrence date for a recurring class
const getNextOccurrenceDate = (recurringDays) => {
  if (!recurringDays || recurringDays.length === 0) {
    // Default to next Monday if no days specified
    recurringDays = ['monday'];
  }
  
  const dayMap = {
    'sunday': 0,
    'monday': 1,
    'tuesday': 2,
    'wednesday': 3,
    'thursday': 4,
    'friday': 5,
    'saturday': 6
  };
  
  const today = new Date();
  const currentDay = today.getDay();
  
  // Convert day names to day numbers
  const dayNumbers = recurringDays.map(day => dayMap[day.toLowerCase()]).filter(d => d !== undefined).sort((a, b) => a - b);
  
  if (dayNumbers.length === 0) {
    // Fallback to next Monday
    dayNumbers.push(1);
  }
  
  // Find the next occurrence (could be today if today is one of the recurring days)
  let daysUntilNext = 0;
  for (const dayNum of dayNumbers) {
    if (dayNum >= currentDay) {
      daysUntilNext = dayNum - currentDay;
      break;
    }
  }
  
  // If no day found this week, use the first day of next week
  if (daysUntilNext === 0 && dayNumbers[0] < currentDay) {
    daysUntilNext = 7 - currentDay + dayNumbers[0];
  }
  
  // If today is one of the recurring days, use today
  if (dayNumbers.includes(currentDay)) {
    daysUntilNext = 0;
  }
  
  const nextDate = new Date(today);
  nextDate.setDate(today.getDate() + daysUntilNext);
  nextDate.setHours(0, 0, 0, 0); // Reset to start of day
  
  return nextDate;
};

// Helper function to transform class for iOS compatibility
const transformClassForIOS = async (classItem, classDates = null) => {
  try {
    console.log(`🔄 Transforming class: ${classItem.name || 'Unknown'}`);
    
    const classObj = classItem.toObject();
    classObj.id = classObj._id;
    delete classObj._id;

    // Ensure location object exists with all required fields
    const location = classObj.location || {};
    const address = location.address || {};
    const coordinates = location.coordinates || {};

  // Get venue data from external APIs if available
  let venueData = null;
  let googlePlacesFormattedAddress = null;
  try {
    console.log(`🔍 Getting venue data for: "${location.name}"`);
    venueData = await venueDataService.getRealVenueData(location.name, address);
    console.log(`🏢 Venue data for "${location.name}":`, {
      parking: venueData.parkingInfo,
      changing: venueData.babyChangingFacilities,
      source: venueData.source
    });

    // Try to get Google Places formatted address for address correction
    if (venueData.source === 'google') {
      try {
        const googleData = await venueDataService.getGooglePlacesData(location.name, address);
        if (googleData && googleData.address) {
          googlePlacesFormattedAddress = googleData.address;
        }
      } catch (e) {
        // Silently fall back to typo correction function
        // Only log if it's a critical error (not just missing data)
        if (e.message && !e.message.includes('missing')) {
          console.log(`⚠️ Could not get Google Places formatted address: ${e.message}`);
        }
      }
    }

    // If no coordinates from venue data, try geocoding the address
    if (!venueData.coordinates && address.street) {
      console.log(`📍 No coordinates from venue data, trying geocoding for: ${address.street}`);
      const geocodedCoords = await venueDataService.getCoordinatesForAddress(address);
      if (geocodedCoords) {
        venueData.coordinates = geocodedCoords;
        console.log(`📍 Geocoded coordinates: ${geocodedCoords.latitude}, ${geocodedCoords.longitude}`);
      }
    }
  } catch (error) {
    console.error('❌ Error getting venue data:', error.message);
    venueData = {
      parkingInfo: getDefaultParkingInfo(location.name),
      babyChangingFacilities: getDefaultChangingFacilities(location.name),
      accessibilityNotes: null,
      coordinates: null,
      source: 'fallback'
    };
  }
  
  // Correct city name - use Google Places formatted address if available, otherwise use correction function
  const originalCity = (address.city || '').trim();
  let correctedCity = correctCityName(originalCity);
  
  if (googlePlacesFormattedAddress) {
    const parsedCity = parseCityFromFormattedAddress(googlePlacesFormattedAddress);
    if (parsedCity && parsedCity !== originalCity) {
      correctedCity = parsedCity;
      console.log(`📍 Corrected city from Google Places: "${originalCity}" -> "${correctedCity}"`);
    }
  } else if (originalCity !== correctedCity) {
    // Only log when there's an actual correction
    console.log(`📍 Corrected city name: "${originalCity}" -> "${correctedCity}"`);
  }

  // Get provider name (business name or full name) and convert provider to string ID
  let providerName = 'Unknown Provider';
  let providerId = classObj.provider;
  
  if (classObj.provider) {
    if (typeof classObj.provider === 'object') {
      // Provider is populated object - extract ID and name
      providerId = classObj.provider._id || classObj.provider.id;
      if (classObj.provider.businessName) {
        providerName = classObj.provider.businessName;
      } else if (classObj.provider.fullName) {
        providerName = classObj.provider.fullName;
      }
    } else if (typeof classObj.provider === 'string') {
      providerName = `Provider ${classObj.provider}`;
    }
  }

  // Determine the start date: prioritize stored classDates from database,
  // then use classDates parameter (when creating a new class),
  // otherwise calculate from recurringDays (for existing classes)
  let startDate;
  
  // First, check if classDates are stored in the database
  let datesToUse = null;
  if (classObj.classDates && Array.isArray(classObj.classDates) && classObj.classDates.length > 0) {
    datesToUse = classObj.classDates;
    console.log(`📅 Found ${datesToUse.length} stored classDates in database`);
  } else if (classDates && Array.isArray(classDates) && classDates.length > 0) {
    // Fallback to classDates parameter (for new classes being created)
    datesToUse = classDates;
    console.log(`📅 Using classDates from parameter`);
  }
  
  if (datesToUse && datesToUse.length > 0) {
    // Process dates - handle both Date objects and date strings
    const dates = datesToUse
      .map(dateInput => {
        // Handle both Date objects and date strings
        const date = dateInput instanceof Date ? dateInput : new Date(dateInput);
        return isNaN(date.getTime()) ? null : date;
      })
      .filter(date => date !== null)
      .sort((a, b) => a.getTime() - b.getTime());
    
    if (dates.length > 0) {
      startDate = dates[0];
      // Reset to start of day
      startDate.setHours(0, 0, 0, 0);
      console.log(`📅 Using classDates start date: ${startDate.toISOString()} (${startDate.toISOString().split('T')[0]})`);
    } else {
      // Fallback to calculating from recurringDays
      startDate = getNextOccurrenceDate(classObj.recurringDays);
      console.log(`📅 classDates invalid, using calculated date: ${startDate.toISOString()} (${startDate.toISOString().split('T')[0]})`);
    }
  } else {
    // Calculate the next occurrence date for this recurring class
    startDate = getNextOccurrenceDate(classObj.recurringDays);
    console.log(`📅 No classDates found, using calculated date from recurringDays: ${startDate.toISOString()} (${startDate.toISOString().split('T')[0]})`);
    console.log(`📅 Class recurringDays:`, classObj.recurringDays || 'none');
  }
  
  const endDate = new Date(startDate);
  endDate.setMonth(endDate.getMonth() + 6); // Set end date to 6 months from start date

  return {
    ...classObj,
    // Convert provider to string ID for iOS compatibility
    provider: providerId,
    // Add provider name for display
    providerName: providerName,
    // Ensure location object matches iOS expectations
    location: {
      id: `location-${classObj.id}`,
      name: location.name || '',
      address: {
        street: (address.street || '').trim(),
        city: correctedCity.trim(),
        state: (address.state || '').trim(),
        postalCode: (address.postalCode || '').trim(),
        country: (address.country || 'United Kingdom').trim()
      },
      coordinates: {
        latitude: venueData?.coordinates?.lat || venueData?.coordinates?.latitude || coordinates.latitude || 0,
        longitude: venueData?.coordinates?.lng || venueData?.coordinates?.longitude || coordinates.longitude || 0
      },
      accessibilityNotes: venueData?.accessibilityNotes || location.accessibilityNotes || null,
      parkingInfo: venueData?.parkingInfo || location.parkingInfo || getDefaultParkingInfo(location.name),
      babyChangingFacilities: venueData?.babyChangingFacilities || location.babyChangingFacilities || getDefaultChangingFacilities(location.name)
    },
    // Create schedule object from recurringDays and timeSlots
    schedule: {
      startDate: startDate,
      endDate: endDate,
      recurringDays: classObj.recurringDays || ['monday'],
      timeSlots: (classObj.timeSlots || []).map(slot => {
        // Parse the time string (e.g., "10:00" or "14:30") and combine with start date
        const timeParts = (slot.startTime || '').split(':');
        const hours = parseInt(timeParts[0] || '0', 10);
        const minutes = parseInt(timeParts[1] || '0', 10);
        
        const slotDate = new Date(startDate);
        slotDate.setHours(hours, minutes, 0, 0);
        
        return {
          startTime: slotDate,
          duration: classObj.duration * 60
        };
      }),
      totalSessions: 1
    },
    // Create pricing object
    pricing: {
      amount: classObj.price,
      currency: 'GBP',
      type: 'perSession',
      description: 'Per session'
    },
    // Map currentBookings to currentEnrollment
    currentEnrollment: classObj.currentBookings || 0,
    // Add isFavorite field
    isFavorite: false
  };
  } catch (error) {
    console.error('❌ Error transforming class:', error.message);
    // Return a basic transformed class with fallback data
    const classObj = classItem.toObject();
    classObj.id = classObj._id;
    delete classObj._id;
    
    // Correct city name in error fallback case too
    const fallbackCity = correctCityName((classObj.location?.address?.city || '').trim());
    
    return {
      ...classObj,
      provider: classObj.provider?._id || classObj.provider,
      providerName: classObj.provider?.businessName || classObj.provider?.fullName || 'Unknown Provider',
      location: {
        name: classObj.location?.name || 'Unknown Venue',
        address: {
          street: (classObj.location?.address?.street || '').trim(),
          city: fallbackCity,
          state: (classObj.location?.address?.state || '').trim(),
          postalCode: (classObj.location?.address?.postalCode || '').trim(),
          country: (classObj.location?.address?.country || 'United Kingdom').trim()
        },
        coordinates: classObj.location?.coordinates || { latitude: 0, longitude: 0 },
        accessibilityNotes: null,
        parkingInfo: 'Street parking available nearby',
        babyChangingFacilities: 'Baby changing facilities available'
      },
      schedule: (() => {
        // Determine the start date: prioritize stored classDates from database,
        // then use classDates parameter, otherwise calculate from recurringDays
        let fallbackStartDate;
        
        // First, check if classDates are stored in the database
        let datesToUse = null;
        if (classObj.classDates && Array.isArray(classObj.classDates) && classObj.classDates.length > 0) {
          datesToUse = classObj.classDates;
        } else if (classDates && Array.isArray(classDates) && classDates.length > 0) {
          datesToUse = classDates;
        }
        
        if (datesToUse && datesToUse.length > 0) {
          // Process dates - handle both Date objects and date strings
          const dates = datesToUse
            .map(dateInput => {
              const date = dateInput instanceof Date ? dateInput : new Date(dateInput);
              return isNaN(date.getTime()) ? null : date;
            })
            .filter(date => date !== null)
            .sort((a, b) => a.getTime() - b.getTime());
          
          if (dates.length > 0) {
            fallbackStartDate = dates[0];
            fallbackStartDate.setHours(0, 0, 0, 0);
          } else {
            fallbackStartDate = getNextOccurrenceDate(classObj.recurringDays || []);
          }
        } else {
          fallbackStartDate = getNextOccurrenceDate(classObj.recurringDays || []);
        }
        
        const endDate = new Date(fallbackStartDate);
        endDate.setMonth(endDate.getMonth() + 6); // Set end date to 6 months from start date
        
        return {
          startDate: fallbackStartDate,
          endDate: endDate,
          recurringDays: classObj.recurringDays || [],
          timeSlots: (classObj.timeSlots || []).map(slot => {
            // Parse the time string (e.g., "10:00" or "14:30") and combine with start date
            const timeParts = (slot.startTime || '').split(':');
            const hours = parseInt(timeParts[0] || '0', 10);
            const minutes = parseInt(timeParts[1] || '0', 10);
            
            const slotDate = new Date(fallbackStartDate);
            slotDate.setHours(hours, minutes, 0, 0);
            
            return {
              startTime: slotDate,
              duration: (classObj.duration || 60) * 60
            };
          }),
          totalSessions: 1
        };
      })(),
      currentEnrollment: classObj.currentBookings || 0,
      isFavorite: false
    };
  }
};

// @route   GET /api/classes
// @desc    Get all published classes with optional filtering
// @access  Public (with optional auth)
router.get('/', optionalAuth, normalizeCategoryInResponse, async (req, res) => {
  try {
    console.log('🔍 GET /api/classes - Fetching published classes');
    
    const {
      category,
      search,
      minPrice,
      maxPrice,
      ageRange,
      location,
      page = 1,
      limit = 20
    } = req.query;

    // Build filter object
    const filter = {
      isActive: true,
      isPublished: true
    };

    // Category filter
    if (category) {
      filter.category = category;
    }

    // Price range filter
    if (minPrice || maxPrice) {
      filter.price = {};
      if (minPrice) filter.price.$gte = parseFloat(minPrice);
      if (maxPrice) filter.price.$lte = parseFloat(maxPrice);
    }

    // Age range filter
    if (ageRange) {
      filter.ageRange = { $regex: ageRange, $options: 'i' };
    }

    // Location filter
    if (location) {
      filter['location.name'] = { $regex: location, $options: 'i' };
    }

    // Text search
    if (search) {
      filter.$text = { $search: search };
    }

    // Pagination
    const skip = (parseInt(page) - 1) * parseInt(limit);

    console.log('🔍 Filter:', JSON.stringify(filter, null, 2));

    // Execute query with provider population
    const classes = await Class.find(filter)
      .populate('provider', 'fullName businessName')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    // Get total count for pagination
    const total = await Class.countDocuments(filter);

    console.log(`✅ Found ${classes.length} published classes (total: ${total})`);

    // Transform classes to match iOS model expectations
    const transformedClasses = await Promise.all(classes.map(transformClassForIOS));

    res.json({
      success: true,
      data: transformedClasses,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit))
      }
    });

  } catch (error) {
    console.error('❌ Get classes error:', error);
    res.status(500).json({ message: 'Server error fetching classes' });
  }
});

// @route   GET /api/classes/:id
// @desc    Get a specific class by ID
// @access  Public
router.get('/:id', async (req, res) => {
  try {
    console.log(`🔍 GET /api/classes/${req.params.id} - Fetching class by ID`);
    
    const classItem = await Class.findById(req.params.id);

    if (!classItem) {
      return res.status(404).json({ message: 'Class not found' });
    }

    if (!classItem.isActive || !classItem.isPublished) {
      return res.status(404).json({ message: 'Class not available' });
    }

    const transformedClass = await transformClassForIOS(classItem);

    res.json({
      success: true,
      data: transformedClass
    });

  } catch (error) {
    console.error('❌ Get class by ID error:', error);
    res.status(500).json({ message: 'Server error fetching class' });
  }
});

// @route   POST /api/classes
// @desc    Create a new class (providers only)
// @access  Private
router.post('/', [
  protect,
  // requireProviderVerification, // Temporarily disabled for testing
  normalizeCategoryInResponse,
  body('name').trim().isLength({ min: 3, max: 100 }),
  body('description').optional().custom((value) => {
    if (value === undefined || value === null || value.trim() === '') {
      return true; // Allow empty/undefined values
    }
    return value.trim().length >= 3; // Validate non-empty values
  }),
  body('category').custom((value) => {
    const normalizedValue = value.charAt(0).toUpperCase() + value.slice(1).toLowerCase();
    return ['Baby', 'Toddler', 'Wellness'].includes(normalizedValue);
  }).withMessage('Category must be one of: baby, toddler, wellness (case insensitive)'),
  body('individualChildSpots').isInt({ min: 0, max: 15 }),
  body('siblingPairs').isInt({ min: 0, max: 15 }),
  body('siblingPrice').isFloat({ min: 0 }),
  body('price').isFloat({ min: 0 }),
  body('adultsPaySame').isBoolean(),
  body('adultPrice').isFloat({ min: 0 }),
  body('adultsFree').isBoolean(),
  body('maxCapacity').isInt({ min: 1 }),
  body('duration').isInt({ min: 15 }),
  body('ageRange').optional().custom((value) => {
    if (value === undefined || value === null || value.trim() === '') {
      return true; // Allow empty/undefined values
    }
    return value.trim().length >= 1; // Validate non-empty values
  }),
  body('recurringDays').optional().isArray(),
  body('timeSlots').isArray({ min: 1 })
], async (req, res) => {
  try {
    console.log('🔍 POST /api/classes - Creating new class');
    console.log('🔍 Request body:', JSON.stringify(req.body, null, 2));
    console.log('🔍 User ID:', req.user.id);

    // Check if user is a provider
    if (req.user.userType !== 'provider') {
      return res.status(403).json({ message: 'Only providers can create classes' });
    }

    // Check for validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        message: 'Validation failed', 
        errors: errors.array() 
      });
    }

    // Create class data
    const classData = {
      ...req.body,
      provider: req.user.id
    };

    // Convert classDates strings to Date objects if provided
    if (req.body.classDates && Array.isArray(req.body.classDates) && req.body.classDates.length > 0) {
      classData.classDates = req.body.classDates.map(dateStr => {
        // Handle "yyyy-MM-dd" format strings (from iOS)
        // Ensure we parse as UTC to avoid timezone issues
        let date;
        if (typeof dateStr === 'string' && dateStr.match(/^\d{4}-\d{2}-\d{2}$/)) {
          // Parse as UTC date to avoid timezone shifts
          const [year, month, day] = dateStr.split('-').map(Number);
          date = new Date(Date.UTC(year, month - 1, day));
        } else {
          date = new Date(dateStr);
        }
        return isNaN(date.getTime()) ? null : date;
      }).filter(date => date !== null);
      
      console.log(`📅 Parsed ${classData.classDates.length} classDates:`, classData.classDates.map(d => d.toISOString().split('T')[0]));
    } else {
      console.log('⚠️ No classDates provided or empty array');
    }

    // Ensure classDates are Date objects before saving (double-check)
    if (classData.classDates && Array.isArray(classData.classDates)) {
      classData.classDates = classData.classDates.map(d => {
        if (d instanceof Date) return d;
        if (typeof d === 'string') {
          const [year, month, day] = d.split('-').map(Number);
          return new Date(Date.UTC(year, month - 1, day));
        }
        return new Date(d);
      }).filter(d => !isNaN(d.getTime()));
    }

    console.log('🔍 Class data to save:', JSON.stringify({
      ...classData,
      classDates: classData.classDates?.map(d => d instanceof Date ? d.toISOString().split('T')[0] : d) || []
    }, null, 2));

    // Create the class
    const newClass = new Class(classData);
    const savedClass = await newClass.save();

    console.log('✅ Class created successfully:', savedClass.name);
    console.log('📅 Saved classDates in database:', savedClass.classDates?.map(d => d.toISOString().split('T')[0]).join(', ') || 'None');

    // Transform the response for iOS compatibility
    // Pass classDates from request body so the start date uses the provider's selected date
    const transformedClass = await transformClassForIOS(savedClass, req.body.classDates || null);

    res.status(201).json({
      success: true,
      message: 'Class created successfully',
      data: transformedClass
    });

  } catch (error) {
    console.error('❌ Create class error:', error);
    res.status(500).json({ message: 'Server error creating class' });
  }
});

// @route   PUT /api/classes/:id
// @desc    Update a class
// @access  Private
router.put('/:id', [
  protect,
  // requireProviderVerification, // Temporarily disabled for testing
  normalizeCategoryInResponse
], async (req, res) => {
  try {
    console.log(`🔍 PUT /api/classes/${req.params.id} - Updating class`);

    const classItem = await Class.findById(req.params.id);

    if (!classItem) {
      return res.status(404).json({ message: 'Class not found' });
    }

    // Check if user owns this class
    if (classItem.provider.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Not authorized to update this class' });
    }

    // Prepare update data
    const updateData = {
      ...req.body,
      updatedAt: new Date()
    };

    // Convert classDates strings to Date objects if provided
    if (req.body.classDates && Array.isArray(req.body.classDates) && req.body.classDates.length > 0) {
      updateData.classDates = req.body.classDates.map(dateStr => {
        // Handle "yyyy-MM-dd" format strings (from iOS)
        // Ensure we parse as UTC to avoid timezone issues
        let date;
        if (typeof dateStr === 'string' && dateStr.match(/^\d{4}-\d{2}-\d{2}$/)) {
          // Parse as UTC date to avoid timezone shifts
          const [year, month, day] = dateStr.split('-').map(Number);
          date = new Date(Date.UTC(year, month - 1, day));
        } else {
          date = new Date(dateStr);
        }
        return isNaN(date.getTime()) ? null : date;
      }).filter(date => date !== null);
      
      console.log(`📅 Parsed ${updateData.classDates.length} classDates for update:`, updateData.classDates.map(d => d.toISOString().split('T')[0]));
    }

    // Update the class
    const updatedClass = await Class.findByIdAndUpdate(
      req.params.id,
      updateData,
      { new: true, runValidators: true }
    );

    console.log('✅ Class updated successfully:', updatedClass.name);

    // Transform the response for iOS compatibility
    const transformedClass = await transformClassForIOS(updatedClass);

    res.json({
      success: true,
      message: 'Class updated successfully',
      data: transformedClass
    });

  } catch (error) {
    console.error('❌ Update class error:', error);
    res.status(500).json({ message: 'Server error updating class' });
  }
});

// @route   POST /api/classes/:id/publish
// @desc    Publish a class
// @access  Private
router.post('/:id/publish', [
  protect,
  // requireProviderVerification, // Temporarily disabled for testing
  normalizeCategoryInResponse
], async (req, res) => {
  try {
    console.log(`🔍 POST /api/classes/${req.params.id}/publish - Publishing class`);

    const classItem = await Class.findById(req.params.id);

    if (!classItem) {
      return res.status(404).json({ message: 'Class not found' });
    }

    // Check if user owns this class
    if (classItem.provider.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Not authorized to publish this class' });
    }

    // Update the class to published
    const updatedClass = await Class.findByIdAndUpdate(
      req.params.id,
      { isPublished: true, updatedAt: new Date() },
      { new: true }
    );

    console.log('✅ Class published successfully:', updatedClass.name);

    // Transform the response for iOS compatibility
    const transformedClass = await transformClassForIOS(updatedClass);

    res.json({
      success: true,
      message: 'Class published successfully',
      data: transformedClass
    });

  } catch (error) {
    console.error('❌ Publish class error:', error);
    res.status(500).json({ message: 'Server error publishing class' });
  }
});

// @route   POST /api/classes/:id/unpublish
// @desc    Unpublish a class
// @access  Private
router.post('/:id/unpublish', [
  protect,
  // requireProviderVerification, // Temporarily disabled for testing
  normalizeCategoryInResponse
], async (req, res) => {
  try {
    console.log(`🔍 POST /api/classes/${req.params.id}/unpublish - Unpublishing class`);

    const classItem = await Class.findById(req.params.id);

    if (!classItem) {
      return res.status(404).json({ message: 'Class not found' });
    }

    // Check if user owns this class
    if (classItem.provider.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Not authorized to unpublish this class' });
    }

    // Update the class to unpublished
    const updatedClass = await Class.findByIdAndUpdate(
      req.params.id,
      { isPublished: false, updatedAt: new Date() },
      { new: true }
    );

    console.log('✅ Class unpublished successfully:', updatedClass.name);

    // Transform the response for iOS compatibility
    const transformedClass = await transformClassForIOS(updatedClass);

    res.json({
      success: true,
      message: 'Class unpublished successfully',
      data: transformedClass
    });

  } catch (error) {
    console.error('❌ Unpublish class error:', error);
    res.status(500).json({ message: 'Server error unpublishing class' });
  }
});

// @route   PUT /api/classes/:id/cancel
// @desc    Cancel a class (mark as cancelled, don't delete)
// @access  Private
router.put('/:id/cancel', [
  protect,
  // requireProviderVerification, // Temporarily disabled for testing
  normalizeCategoryInResponse
], async (req, res) => {
  try {
    console.log(`🔍 PUT /api/classes/${req.params.id}/cancel - Cancelling class`);

    const classItem = await Class.findById(req.params.id);

    if (!classItem) {
      return res.status(404).json({ message: 'Class not found' });
    }

    // Check if user owns this class
    if (classItem.provider.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Not authorized to cancel this class' });
    }

    // Mark class as inactive (cancelled)
    const updatedClass = await Class.findByIdAndUpdate(
      req.params.id,
      { isActive: false, updatedAt: new Date() },
      { new: true }
    );

    console.log('✅ Class cancelled successfully:', updatedClass.name);

    // Transform the response for iOS compatibility
    const transformedClass = await transformClassForIOS(updatedClass);

    res.json({
      success: true,
      message: 'Class cancelled successfully',
      data: transformedClass
    });

  } catch (error) {
    console.error('❌ Cancel class error:', error);
    res.status(500).json({ message: 'Server error cancelling class' });
  }
});

// @route   DELETE /api/classes/:id
// @desc    Delete a class
// @access  Private
router.delete('/:id', [
  protect,
  // requireProviderVerification, // Temporarily disabled for testing
  normalizeCategoryInResponse
], async (req, res) => {
  try {
    console.log(`🔍 DELETE /api/classes/${req.params.id} - Deleting class`);

    const classItem = await Class.findById(req.params.id);

    if (!classItem) {
      return res.status(404).json({ message: 'Class not found' });
    }

    // Check if user owns this class
    if (classItem.provider.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Not authorized to delete this class' });
    }

    // Delete the class
    await Class.findByIdAndDelete(req.params.id);

    console.log('✅ Class deleted successfully:', classItem.name);

    res.json({
      success: true,
      message: 'Class deleted successfully'
    });

  } catch (error) {
    console.error('❌ Delete class error:', error);
    res.status(500).json({ message: 'Server error deleting class' });
  }
});

// @route   GET /api/classes/provider/my-classes
// @desc    Get all classes for the authenticated provider
// @access  Private
router.get('/provider/my-classes', protect, /* requireProviderVerification, */ normalizeCategoryInResponse, async (req, res) => {
  try {
    console.log('🔍 GET /api/classes/provider/my-classes - Fetching provider classes');
    console.log('🔍 Provider ID:', req.user.id);

    const { status, page = 1, limit = 20 } = req.query;

    const filter = {
      provider: req.user.id
    };

    // Filter by status
    if (status === 'published') {
      filter.isPublished = true;
    } else if (status === 'draft') {
      filter.isPublished = false;
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const classes = await Class.find(filter)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    const total = await Class.countDocuments(filter);

    console.log(`✅ Found ${classes.length} classes for provider (total: ${total})`);

    // Transform classes to match iOS model expectations
    const transformedClasses = await Promise.all(classes.map(transformClassForIOS));

    res.json({
      success: true,
      data: transformedClasses,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit))
      }
    });

  } catch (error) {
    console.error('❌ Get provider classes error:', error);
    res.status(500).json({ message: 'Server error fetching provider classes' });
  }
});

// @route   POST /api/classes/venues/analyze
// @desc    Analyze a venue and get detailed information
// @access  Private
router.post('/venues/analyze', protect, async (req, res) => {
  try {
    const { venueName, address } = req.body;

    if (!venueName || !address) {
      return res.status(400).json({ 
        message: 'Venue name and address are required' 
      });
    }

    console.log(`🔍 Analyzing venue: ${venueName} at ${address.street}, ${address.city}`);
    console.log(`🔄 Venue analysis: Force refresh enabled - will fetch fresh data including transit stations`);

    // Get real venue data from external APIs (force refresh to get latest data including transit stations)
    const venueData = await venueDataService.getRealVenueData(venueName, address, true);
    
    console.log(`📊 Venue analysis result for ${venueName}:`, {
      parkingInfo: venueData.parkingInfo,
      hasTransitStations: venueData.parkingInfo?.includes('stations:') || venueData.parkingInfo?.includes('station'),
      source: venueData.source
    });

    // Get coordinates if not already available
    let coordinates = venueData.coordinates;
    if (!coordinates && address.street) {
      coordinates = await venueDataService.getCoordinatesForAddress(address);
    }

    res.json({
      success: true,
      data: {
        venueName: venueName,
        address: address,
        coordinates: coordinates,
        parkingInfo: venueData.parkingInfo,
        babyChangingFacilities: venueData.babyChangingFacilities,
        accessibilityNotes: venueData.accessibilityNotes,
        source: venueData.source,
        lastUpdated: venueData.lastUpdated || new Date().toISOString()
      }
    });

  } catch (error) {
    console.error('❌ Venue analysis error:', error);
    res.status(500).json({ 
      message: 'Server error analyzing venue',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

module.exports = router;
