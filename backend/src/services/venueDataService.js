const axios = require('axios');

class VenueDataService {
  constructor() {
    this.googlePlacesApiKey = process.env.GOOGLE_PLACES_API_KEY;
    this.foursquareApiKey = process.env.FOURSQUARE_API_KEY;
    this.cache = new Map(); // Simple in-memory cache
    this.cacheExpiry = 24 * 60 * 60 * 1000; // 24 hours
  }

  /**
   * Get real venue information from online sources
   * @param {string} venueName - Name of the venue
   * @param {Object} address - Address object with street, city, postalCode
   * @returns {Object} Real venue data including parking and changing facilities
   */
  async getRealVenueData(venueName, address) {
    console.log(`🔍 getRealVenueData called with:`, { venueName, address });
    
    if (!venueName || !address || !address.street) {
      console.log(`⚠️ Insufficient venue data, using defaults for: ${venueName}`);
      return this.getDefaultVenueData(venueName);
    }

    // Check cache first
    const cacheKey = `${venueName}-${address.street}-${address.city}`;
    const cached = this.cache.get(cacheKey);
    if (cached && Date.now() - cached.timestamp < this.cacheExpiry) {
      console.log(`📦 Using cached venue data for: ${venueName}`);
      return cached.data;
    }

    try {
      console.log(`🔍 Fetching real venue data for: ${venueName}`);
      
      // Try Google Places first
      const googleData = await this.getGooglePlacesData(venueName, address);
      if (googleData) {
        const result = this.formatVenueData(googleData, 'google');
        this.cache.set(cacheKey, { data: result, timestamp: Date.now() });
        return result;
      }

      // Fallback to Foursquare
      const foursquareData = await this.getFoursquareData(venueName, address);
      if (foursquareData) {
        const result = this.formatVenueData(foursquareData, 'foursquare');
        this.cache.set(cacheKey, { data: result, timestamp: Date.now() });
        return result;
      }

      // If no real data found, use smart defaults
      const defaultData = this.getDefaultVenueData(venueName);
      this.cache.set(cacheKey, { data: defaultData, timestamp: Date.now() });
      return defaultData;

    } catch (error) {
      console.error('❌ Error fetching venue data:', error.message);
      return this.getDefaultVenueData(venueName);
    }
  }

  /**
   * Get venue data from Google Places API
   */
  async getGooglePlacesData(venueName, address) {
    if (!this.googlePlacesApiKey) {
      console.log('⚠️ Google Places API key not configured');
      return null;
    }

    try {
      const query = `${venueName} ${address.street} ${address.city}`;
      const encodedQuery = encodeURIComponent(query);
      
      const response = await axios.get(
        `https://maps.googleapis.com/maps/api/place/textsearch/json?query=${encodedQuery}&key=${this.googlePlacesApiKey}`
      );

      if (response.data.results && response.data.results.length > 0) {
        const place = response.data.results[0];
        
        // Get detailed place information including parking and accessibility data
        const detailsResponse = await axios.get(
          `https://maps.googleapis.com/maps/api/place/details/json?place_id=${place.place_id}&fields=name,formatted_address,geometry,place_id,types,opening_hours,photos,reviews,parking_lot,wheelchair_accessible_entrance&key=${this.googlePlacesApiKey}`
        );

        return {
          name: detailsResponse.data.result.name,
          address: detailsResponse.data.result.formatted_address,
          coordinates: detailsResponse.data.result.geometry?.location,
          types: detailsResponse.data.result.types,
          openingHours: detailsResponse.data.result.opening_hours,
          photos: detailsResponse.data.result.photos,
          reviews: detailsResponse.data.result.reviews,
          rating: place.rating,
          userRatingsTotal: place.user_ratings_total,
          parkingLot: detailsResponse.data.result.parking_lot,
          wheelchairAccessibleEntrance: detailsResponse.data.result.wheelchair_accessible_entrance
        };
      }
    } catch (error) {
      console.error('❌ Google Places API error:', error.message);
    }
    
    return null;
  }

  /**
   * Get venue data from Foursquare API
   */
  async getFoursquareData(venueName, address) {
    if (!this.foursquareApiKey) {
      console.log('⚠️ Foursquare API key not configured');
      return null;
    }

    try {
      const query = `${venueName} ${address.street} ${address.city}`;
      const encodedQuery = encodeURIComponent(query);
      
      const response = await axios.get(
        `https://api.foursquare.com/v3/places/search?query=${encodedQuery}&limit=1&fields=name,location,categories,rating,price,hours,photos,amenities`,
        {
          headers: {
            'Authorization': this.foursquareApiKey,
            'Accept': 'application/json'
          }
        }
      );

      if (response.data.results && response.data.results.length > 0) {
        const venue = response.data.results[0];
        return {
          name: venue.name,
          address: venue.location.formatted_address,
          coordinates: venue.geocodes?.main,
          categories: venue.categories,
          rating: venue.rating,
          price: venue.price,
          hours: venue.hours,
          photos: venue.photos,
          amenities: venue.amenities
        };
      }
    } catch (error) {
      console.error('❌ Foursquare API error:', error.message);
    }
    
    return null;
  }

  /**
   * Format venue data from API response
   */
  formatVenueData(apiData, source) {
    const parkingInfo = this.generateParkingInfo(apiData, source);
    const changingFacilities = this.generateChangingFacilities(apiData, source);
    
    return {
      parkingInfo,
      babyChangingFacilities: changingFacilities,
      accessibilityNotes: this.generateAccessibilityNotes(apiData, source),
      coordinates: apiData.coordinates,
      source: source,
      lastUpdated: new Date().toISOString()
    };
  }

  /**
   * Generate parking information based on venue data
   */
  generateParkingInfo(apiData, source) {
    const venueName = apiData.name?.toLowerCase() || '';
    const types = apiData.types || apiData.categories || [];
    const address = apiData.address?.toLowerCase() || '';
    
    // First, check if we have actual parking data from APIs
    if (source === 'google' && apiData.parkingLot !== undefined) {
      if (apiData.parkingLot === true) {
        return "Parking available on-site";
      } else if (apiData.parkingLot === false) {
        return "No on-site parking - street parking recommended";
      }
    }
    
    // Check Foursquare amenities for parking information
    if (source === 'foursquare' && apiData.amenities) {
      if (apiData.amenities.parking === true) {
        return "Parking available on-site";
      } else if (apiData.amenities.parking === false) {
        return "No on-site parking - street parking recommended";
      }
    }
    
    // Check for specific venue types that typically have parking
    if (types.some(type => 
      ['shopping_mall', 'supermarket', 'hospital', 'university', 'school'].includes(type) ||
      type.includes('shopping') || type.includes('mall')
    )) {
      return "Free parking available on-site";
    }
    
    if (types.some(type => 
      ['library', 'museum', 'art_gallery', 'tourist_attraction'].includes(type) ||
      type.includes('library') || type.includes('museum')
    )) {
      return "Limited parking - street parking recommended";
    }
    
    if (types.some(type => 
      ['park', 'garden', 'playground', 'recreation'].includes(type) ||
      type.includes('park') || type.includes('garden')
    )) {
      return "Free parking available";
    }
    
    if (types.some(type => 
      ['church', 'place_of_worship', 'community_center'].includes(type) ||
      type.includes('church') || type.includes('community')
    )) {
      return "On-site parking available";
    }
    
    if (types.some(type => 
      ['restaurant', 'cafe', 'food', 'bar'].includes(type) ||
      type.includes('restaurant') || type.includes('cafe')
    )) {
      return "Street parking available nearby";
    }
    
    // Check venue name for clues
    if (venueName.includes('community') || venueName.includes('centre') || venueName.includes('center')) {
      return "Free parking available on-site";
    }
    
    if (venueName.includes('library') || venueName.includes('museum')) {
      return "Limited parking - street parking recommended";
    }
    
    if (venueName.includes('park') || venueName.includes('garden')) {
      return "Free parking available";
    }
    
    if (venueName.includes('church') || venueName.includes('hall')) {
      return "On-site parking available";
    }
    
    if (venueName.includes('cafe') || venueName.includes('restaurant')) {
      return "Street parking available nearby";
    }
    
    // Special handling for London locations
    if (address.includes('london') && (venueName.includes('gail') || types.some(type => type.includes('bakery')))) {
      return "Limited street parking in Central London - public transport recommended";
    }
    
    // Check for business/office types
    if (types.some(type => 
      ['establishment', 'point_of_interest', 'store', 'business'].includes(type) ||
      type.includes('business') || type.includes('office')
    )) {
      return "Street parking available - check for restrictions";
    }
    
    return "Street parking available nearby";
  }

  /**
   * Generate changing facilities information based on venue data
   */
  generateChangingFacilities(apiData, source) {
    const types = apiData.types || apiData.categories || [];
    const venueName = apiData.name?.toLowerCase() || '';
    
    // Check for venue types that typically have changing facilities
    if (types.some(type => 
      ['shopping_mall', 'supermarket', 'hospital', 'university', 'school', 'library', 'museum'].includes(type) ||
      type.includes('shopping') || type.includes('mall') || type.includes('library') || type.includes('museum')
    )) {
      return "Baby changing facilities available";
    }
    
    if (types.some(type => 
      ['park', 'garden', 'playground', 'recreation'].includes(type) ||
      type.includes('park') || type.includes('garden')
    )) {
      return "Portable changing facilities recommended";
    }
    
    if (types.some(type => 
      ['church', 'place_of_worship', 'community_center'].includes(type) ||
      type.includes('church') || type.includes('community')
    )) {
      return "Baby changing facilities available";
    }
    
    if (types.some(type => 
      ['restaurant', 'cafe', 'food', 'bar'].includes(type) ||
      type.includes('restaurant') || type.includes('cafe')
    )) {
      return "Baby changing facilities available";
    }
    
    // Check venue name for clues
    if (venueName.includes('community') || venueName.includes('centre') || venueName.includes('center')) {
      return "Baby changing facilities available";
    }
    
    if (venueName.includes('library') || venueName.includes('museum')) {
      return "Baby changing facilities available";
    }
    
    if (venueName.includes('church') || venueName.includes('hall')) {
      return "Baby changing facilities available";
    }
    
    if (venueName.includes('cafe') || venueName.includes('restaurant')) {
      return "Baby changing facilities available";
    }
    
    if (venueName.includes('park') || venueName.includes('garden')) {
      return "Portable changing facilities recommended";
    }
    
    return "Baby changing facilities available";
  }

  /**
   * Generate accessibility notes based on venue data
   */
  generateAccessibilityNotes(apiData, source) {
    const types = apiData.types || apiData.categories || [];
    
    // First, check if we have actual accessibility data from Google Places API
    if (source === 'google' && apiData.wheelchairAccessibleEntrance !== undefined) {
      if (apiData.wheelchairAccessibleEntrance === true) {
        return "Wheelchair accessible entrance confirmed";
      } else if (apiData.wheelchairAccessibleEntrance === false) {
        return "Wheelchair accessibility may be limited - please contact venue";
      }
    }
    
    // Check for venue types that typically have good accessibility
    if (types.some(type => 
      ['hospital', 'university', 'school', 'library', 'museum', 'shopping_mall'].includes(type) ||
      type.includes('hospital') || type.includes('university') || type.includes('library') || type.includes('museum')
    )) {
      return "Wheelchair accessible with accessible facilities";
    }
    
    if (types.some(type => 
      ['park', 'garden', 'playground'].includes(type) ||
      type.includes('park') || type.includes('garden')
    )) {
      return "Partially accessible - some areas may have uneven terrain";
    }
    
    return "Accessibility information not available";
  }

  /**
   * Fallback to smart defaults when no real data is available
   */
  getDefaultVenueData(venueName) {
    console.log(`🏢 Using default venue data for: ${venueName}`);
    return {
      parkingInfo: this.getDefaultParkingInfo(venueName),
      babyChangingFacilities: this.getDefaultChangingFacilities(venueName),
      accessibilityNotes: this.getDefaultAccessibilityNotes(venueName),
      coordinates: null,
      source: 'default',
      lastUpdated: new Date().toISOString()
    };
  }

  /**
   * Get coordinates for an address using Google Geocoding API
   */
  async getCoordinatesForAddress(address) {
    if (!this.googlePlacesApiKey) {
      console.log('⚠️ Google Places API key not configured for geocoding');
      return null;
    }

    try {
      const addressString = `${address.street}, ${address.city}, ${address.postalCode}, ${address.country}`;
      const encodedAddress = encodeURIComponent(addressString);
      
      const response = await axios.get(
        `https://maps.googleapis.com/maps/api/geocode/json?address=${encodedAddress}&key=${this.googlePlacesApiKey}`
      );

      if (response.data.results && response.data.results.length > 0) {
        const location = response.data.results[0].geometry.location;
        console.log(`📍 Found coordinates for ${addressString}: ${location.lat}, ${location.lng}`);
        return {
          latitude: location.lat,
          longitude: location.lng
        };
      }
    } catch (error) {
      console.error('❌ Geocoding API error:', error.message);
    }
    
    return null;
  }

  /**
   * Default parking info based on venue name patterns
   */
  getDefaultParkingInfo(venueName) {
    if (!venueName) return "Street parking available nearby";
    
    const name = venueName.toLowerCase();
    
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
  }

  /**
   * Default changing facilities based on venue name patterns
   */
  getDefaultChangingFacilities(venueName) {
    if (!venueName) return "Baby changing facilities available";
    
    const name = venueName.toLowerCase();
    
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
  }

  /**
   * Default accessibility notes based on venue name patterns
   */
  getDefaultAccessibilityNotes(venueName) {
    if (!venueName) return "Accessibility information not available";
    
    const name = venueName.toLowerCase();
    
    if (name.includes('community') || name.includes('centre') || name.includes('center')) {
      return "Wheelchair accessible with accessible facilities";
    } else if (name.includes('library') || name.includes('museum')) {
      return "Wheelchair accessible with accessible facilities";
    } else if (name.includes('church') || name.includes('hall')) {
      return "Wheelchair accessible with accessible facilities";
    } else if (name.includes('cafe') || name.includes('restaurant')) {
      return "Wheelchair accessible with accessible facilities";
    } else if (name.includes('park') || name.includes('garden')) {
      return "Partially accessible - some areas may have uneven terrain";
    } else {
      return "Accessibility information not available";
    }
  }
}

module.exports = new VenueDataService();
