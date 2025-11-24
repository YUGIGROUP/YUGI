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

    // Check cache first (but skip if it's default data - we want to retry APIs)
    const cacheKey = `${venueName}-${address.street}-${address.city}`.toLowerCase().trim();
    const cached = this.cache.get(cacheKey);
    if (cached && Date.now() - cached.timestamp < this.cacheExpiry) {
      // Don't use cached default data - always retry APIs for better data
      // Also clear old cache entries that don't have a source field (from before the fix)
      if (!cached.data || !cached.data.source || cached.data.source === 'default') {
        console.log(`🔄 Cached data is default or missing source, clearing cache and retrying APIs for: ${venueName}`);
        // Clear the default/old cache entry
        this.cache.delete(cacheKey);
      } else {
        console.log(`📦 Using cached venue data for: ${venueName} (source: ${cached.data.source})`);
        return cached.data;
      }
    }

    try {
      console.log(`🔍 Fetching real venue data for: ${venueName}`);
      
      // Try Google Places first
      const googleData = await this.getGooglePlacesData(venueName, address);
      if (googleData && googleData.name) {
        console.log(`✅ Google Places data retrieved for: ${venueName}`);
        
        // Find nearby transit stations if we have coordinates
        let nearbyStations = [];
        if (googleData.coordinates && googleData.coordinates.lat && googleData.coordinates.lng) {
          nearbyStations = await this.findNearbyTransitStations(
            googleData.coordinates.lat,
            googleData.coordinates.lng
          );
          console.log(`🚇 getRealVenueData: Found ${nearbyStations.length} transit stations: ${nearbyStations.join(', ')}`);
        } else {
          console.log(`🚇 getRealVenueData: No coordinates available for transit station lookup`);
        }
        
        const result = this.formatVenueData(googleData, 'google', nearbyStations);
        // Only cache real API data (not default data)
        if (result && result.source && result.source !== 'default') {
          const normalizedCacheKey = `${venueName}-${address.street}-${address.city}`.toLowerCase().trim();
          this.cache.set(normalizedCacheKey, { data: result, timestamp: Date.now() });
          console.log(`💾 Cached venue data for: ${venueName} (source: ${result.source})`);
        }
        return result;
      }

      // Fallback to Foursquare
      const foursquareData = await this.getFoursquareData(venueName, address);
      if (foursquareData && foursquareData.name) {
        console.log(`✅ Foursquare data retrieved for: ${venueName}`);
        const result = this.formatVenueData(foursquareData, 'foursquare');
        // Only cache real API data (not default data)
        if (result && result.source && result.source !== 'default') {
          const normalizedCacheKey = `${venueName}-${address.street}-${address.city}`.toLowerCase().trim();
          this.cache.set(normalizedCacheKey, { data: result, timestamp: Date.now() });
          console.log(`💾 Cached venue data for: ${venueName} (source: ${result.source})`);
        }
        return result;
      }

      // If no real data found, use smart defaults (but don't cache them)
      console.log(`⚠️ No API data found, using defaults for: ${venueName}`);
      const defaultData = this.getDefaultVenueData(venueName);
      // Don't cache default data - allow retry on next request
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

    // Verify API key format (should start with AIza)
    if (!this.googlePlacesApiKey.startsWith('AIza')) {
      console.log('⚠️ Google Places API key format appears invalid (should start with "AIza")');
      console.log('⚠️ API key preview:', this.googlePlacesApiKey.substring(0, 10) + '...');
    }

    let response;
    try {
      // Safely construct query - check if address exists
      if (!address || typeof address !== 'object') {
        console.log('⚠️ Google Places: Invalid address object provided');
        return null;
      }
      
      const street = address.street || '';
      const city = address.city || '';
      const query = `${venueName} ${street} ${city}`.trim();
      const encodedQuery = encodeURIComponent(query);
      
      console.log(`🔍 Google Places: Searching for "${venueName}" at "${street}, ${city}"`);
      console.log(`🔍 Google Places: Query string: "${query}"`);
      console.log(`🔍 Google Places: API key configured: ${!!this.googlePlacesApiKey} (length: ${this.googlePlacesApiKey?.length || 0})`);
      
      const apiUrl = `https://maps.googleapis.com/maps/api/place/textsearch/json?query=${encodedQuery}&key=${this.googlePlacesApiKey}`;
      console.log(`🔍 Google Places: Making request to: ${apiUrl.replace(this.googlePlacesApiKey, 'API_KEY_HIDDEN')}`);
      
      response = await axios.get(apiUrl);

      // Log response structure for debugging
      if (!response) {
        console.log('⚠️ Google Places: No response object');
        return null;
      }
      
      if (!response.data) {
        console.log('⚠️ Google Places: No response.data');
        console.log('⚠️ Response object:', JSON.stringify(response, null, 2));
        return null;
      }
      
      // Log full response structure for debugging
      console.log('🔍 Google Places API response structure:', {
        hasData: !!response.data,
        dataType: typeof response.data,
        hasStatus: !!(response.data && response.data.status),
        status: response.data?.status,
        hasResults: !!(response.data && response.data.results),
        resultsType: response.data?.results ? typeof response.data.results : 'N/A',
        resultsIsArray: Array.isArray(response.data?.results),
        resultsLength: Array.isArray(response.data?.results) ? response.data.results.length : 0
      });
      
      // Log the full response data for debugging (truncated if too large)
      try {
        const responseStr = JSON.stringify(response.data, null, 2);
        if (responseStr.length > 5000) {
          console.log('🔍 Google Places API full response (truncated):', responseStr.substring(0, 5000) + '...');
        } else {
          console.log('🔍 Google Places API full response:', responseStr);
        }
      } catch (e) {
        console.log('⚠️ Could not stringify response data:', e.message);
      }

      const responseStatus = (response.data && typeof response.data === 'object' && response.data.status) ? response.data.status : 'unknown';
      console.log(`🔍 Google Places API response status: ${responseStatus}`);

      // Check for API errors first
      if (response.data && typeof response.data === 'object' && response.data.status && response.data.status !== 'OK' && response.data.status !== 'ZERO_RESULTS') {
        console.log(`⚠️ Google Places API returned status: ${response.data.status}`);
        if (response.data.error_message) {
          console.log(`⚠️ Google Places error message: ${response.data.error_message}`);
        }
        return null;
      }

      if (response.data && typeof response.data === 'object' && response.data.results && Array.isArray(response.data.results) && response.data.results.length > 0) {
        try {
          // Double-check that we can safely access the first element
          if (response.data.results[0] === undefined || response.data.results[0] === null) {
            console.log('⚠️ Google Places: First result is undefined or null even though array has length > 0');
            console.log('⚠️ Results array length:', response.data.results.length);
            console.log('⚠️ Results array:', JSON.stringify(response.data.results.slice(0, 2), null, 2));
            return null;
          }
          
          const place = response.data.results[0];
          
          // More defensive check - ensure place exists and is an object
          if (!place) {
            console.log('⚠️ Google Places: First result is falsy (null, undefined, false, 0, "", etc.)');
            console.log('⚠️ First result value:', place);
            console.log('⚠️ Results array length:', response.data.results.length);
            return null;
          }
          
          if (typeof place !== 'object') {
            console.log('⚠️ Google Places: First result is not an object');
            console.log('⚠️ First result type:', typeof place);
            console.log('⚠️ First result value:', place);
            return null;
          }
          
          if (place === null) {
            console.log('⚠️ Google Places: First result is explicitly null');
            return null;
          }
          
          // Safely check for place_id
          const placeId = (place && typeof place === 'object' && place.place_id) ? place.place_id : null;
          if (!placeId) {
            console.log('⚠️ Google Places: No place_id found in search results');
            console.log('⚠️ Place object keys:', Object.keys(place || {}));
            console.log('⚠️ Place object:', JSON.stringify(place, null, 2));
            return null;
          }
          
          // Safely get place name - use optional chaining equivalent
          let placeName = 'unnamed';
          try {
            if (place && typeof place === 'object' && 'name' in place) {
              placeName = place.name || 'unnamed';
            }
          } catch (e) {
            console.log('⚠️ Error accessing place.name:', e.message);
            placeName = 'unnamed';
          }
          console.log(`🔍 Google Places: Found place "${placeName}" with place_id: ${placeId}`);
        
        // Get detailed place information including parking and accessibility data
        // Note: parking_lot is not a valid field - parking info comes from reviews/editorial_summary
        console.log(`🔍 Google Places: Fetching details for place_id: ${placeId}`);
        const detailsResponse = await axios.get(
          `https://maps.googleapis.com/maps/api/place/details/json?place_id=${placeId}&fields=name,formatted_address,geometry,place_id,types,opening_hours,photos,reviews,wheelchair_accessible_entrance,editorial_summary&key=${this.googlePlacesApiKey}`
        );

        // Log details response structure
        console.log('🔍 Google Places Details API response structure:', {
          hasResponse: !!detailsResponse,
          hasData: !!(detailsResponse && detailsResponse.data),
          dataType: detailsResponse?.data ? typeof detailsResponse.data : 'N/A',
          hasStatus: !!(detailsResponse?.data?.status),
          status: detailsResponse?.data?.status,
          hasResult: !!(detailsResponse?.data?.result),
          resultType: detailsResponse?.data?.result ? typeof detailsResponse.data.result : 'N/A'
        });

        // Log full details response for debugging
        try {
          const detailsStr = JSON.stringify(detailsResponse?.data, null, 2);
          if (detailsStr && detailsStr.length > 5000) {
            console.log('🔍 Google Places Details API full response (truncated):', detailsStr.substring(0, 5000) + '...');
          } else if (detailsStr) {
            console.log('🔍 Google Places Details API full response:', detailsStr);
          }
        } catch (e) {
          console.log('⚠️ Could not stringify details response data:', e.message);
        }

        // Check for API errors in details response
        if (detailsResponse?.data?.status && detailsResponse.data.status !== 'OK') {
          console.log(`⚠️ Google Places Details API returned status: ${detailsResponse.data.status}`);
          if (detailsResponse.data.error_message) {
            console.log(`⚠️ Google Places Details error message: ${detailsResponse.data.error_message}`);
          }
          return null;
        }

        if (!detailsResponse || !detailsResponse.data || !detailsResponse.data.result) {
          console.log('⚠️ Google Places: No result in details response');
          console.log('⚠️ Details response structure:', {
            detailsResponse: !!detailsResponse,
            detailsResponseData: !!(detailsResponse && detailsResponse.data),
            detailsResponseDataResult: !!(detailsResponse && detailsResponse.data && detailsResponse.data.result)
          });
          if (detailsResponse?.data?.error_message) {
            console.log('⚠️ Google Places error message:', detailsResponse.data.error_message);
          }
          return null;
        }

        const result = detailsResponse.data.result;
        
        // More defensive check for result
        if (!result) {
          console.log('⚠️ Google Places: result is falsy (null, undefined, false, 0, "", etc.)');
          console.log('⚠️ Result value:', result);
          console.log('⚠️ Details response data:', JSON.stringify(detailsResponse.data, null, 2));
          return null;
        }
        
        if (typeof result !== 'object') {
          console.log('⚠️ Google Places: result is not an object');
          console.log('⚠️ Result type:', typeof result);
          console.log('⚠️ Result value:', result);
          return null;
        }
        
        if (result === null) {
          console.log('⚠️ Google Places: result is explicitly null');
          return null;
        }
        
        // Safely get result name - use try-catch to handle any edge cases
        let resultName = venueName;
        try {
          if (result && typeof result === 'object' && 'name' in result) {
            resultName = result.name || venueName;
          }
        } catch (e) {
          console.log('⚠️ Error accessing result.name:', e.message);
          resultName = venueName;
        }
        console.log(`✅ Google Places: Successfully retrieved details for "${resultName}"`);
        
        // Safely extract coordinates
        let coordinates = null;
        if (result.geometry && typeof result.geometry === 'object' && result.geometry.location) {
          const loc = result.geometry.location;
          if (loc && typeof loc === 'object') {
            coordinates = {
              lat: typeof loc.lat === 'number' ? loc.lat : (loc.lat ? parseFloat(loc.lat) : null),
              lng: typeof loc.lng === 'number' ? loc.lng : (loc.lng ? parseFloat(loc.lng) : null)
            };
          }
        }
        
        // Safely access place properties (place is from search results, result is from details)
        const placeRating = (place && typeof place === 'object' && place.rating) ? place.rating : null;
        const placeUserRatingsTotal = (place && typeof place === 'object' && place.user_ratings_total) ? place.user_ratings_total : null;
        
        // Safely build return object with all defensive checks
        try {
          // Safely get address - ensure address object exists
          let formattedAddress = `${address.street || ''}, ${address.city || ''}`.replace(/^,\s*|,\s*$/g, '').trim();
          if (result && typeof result === 'object' && result.formatted_address) {
            formattedAddress = result.formatted_address;
          }
          
          // Safely get all properties
          const returnObject = {
            name: resultName,
            address: formattedAddress,
            coordinates: coordinates,
            types: (result && Array.isArray(result.types)) ? result.types : [],
            openingHours: (result && result.opening_hours) ? result.opening_hours : null,
            photos: (result && result.photos) ? result.photos : null,
            reviews: (result && Array.isArray(result.reviews)) ? result.reviews : [],
            rating: placeRating,
            userRatingsTotal: placeUserRatingsTotal,
            parkingLot: (result && result.parking_lot !== undefined) ? result.parking_lot : null,
            wheelchairAccessibleEntrance: (result && result.wheelchair_accessible_entrance !== undefined) ? result.wheelchair_accessible_entrance : null,
            editorialSummary: (result && result.editorial_summary && typeof result.editorial_summary === 'object' && result.editorial_summary.overview) ? result.editorial_summary.overview : null
          };
          
          console.log(`✅ Google Places: Successfully built return object with name: "${returnObject.name}"`);
          return returnObject;
        } catch (buildError) {
          console.error('❌ Error building Google Places return object:', buildError.message);
          console.error('❌ Build error stack:', buildError.stack);
          console.error('❌ Result object keys:', result ? Object.keys(result) : 'result is null/undefined');
          console.error('❌ Address object:', address);
          // Re-throw to be caught by outer catch
          throw buildError;
        }
        } catch (innerError) {
          console.error('❌ Error processing Google Places search results:', innerError.message);
          console.error('❌ Inner error stack:', innerError.stack);
          // Re-throw to be caught by outer catch
          throw innerError;
        }
      } else {
        console.log('⚠️ Google Places: No results found in search response');
        if (response && response.data && response.data.error_message) {
          console.log('⚠️ Google Places error message:', response.data.error_message);
        }
      }
    } catch (error) {
      // Safely log error message
      const errorMessage = (error && error.message) ? error.message : 'Unknown error';
      console.error('❌ Google Places API error:', errorMessage);
      
      // Safely log error type
      try {
        const errorType = (error && error.constructor && error.constructor.name) ? error.constructor.name : 'Unknown';
        console.error('❌ Error type:', errorType);
      } catch (e) {
        console.error('❌ Could not determine error type');
      }
      
      // Safely log response if it exists
      if (error && error.response) {
        try {
          console.error('❌ Google Places API response status:', error.response.status);
          if (error.response.data) {
            console.error('❌ Google Places API response data:', JSON.stringify(error.response.data, null, 2));
          }
        } catch (e) {
          console.error('❌ Error logging response data:', e.message);
        }
      }
      
      // Safely log stack trace
      if (error && error.stack) {
        console.error('❌ Google Places API error stack:', error.stack);
      }
      
      // Log the exact line where error occurred if possible
      if (errorMessage.includes('Cannot read properties')) {
        console.error('❌ This appears to be a null/undefined access error.');
        console.error('❌ Error message:', errorMessage);
        // Try to log what we have - check if response exists
        try {
          if (typeof response !== 'undefined' && response) {
            console.error('❌ Response exists:', true);
            console.error('❌ Response.data exists:', !!(response.data));
            if (response.data) {
              console.error('❌ Response.data.status:', response.data.status);
              console.error('❌ Response.data.results exists:', !!(response.data.results));
              if (response.data.results && Array.isArray(response.data.results) && response.data.results.length > 0) {
                const firstResult = response.data.results[0];
                console.error('❌ First result exists:', !!firstResult);
                console.error('❌ First result type:', typeof firstResult);
                if (firstResult && typeof firstResult === 'object') {
                  console.error('❌ First result has name property:', 'name' in firstResult);
                  console.error('❌ First result keys:', Object.keys(firstResult).slice(0, 10));
                }
              }
            }
          } else {
            console.error('❌ Response is undefined - error occurred before API call completed');
          }
        } catch (e) {
          console.error('❌ Error logging debug info:', (e && e.message) ? e.message : 'Unknown error');
        }
      }
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

    // Safely check address
    if (!address || typeof address !== 'object') {
      console.log('⚠️ Foursquare: Invalid address object provided');
      return null;
    }

    try {
      const street = address.street || '';
      const city = address.city || '';
      const query = `${venueName} ${street} ${city}`.trim();
      const encodedQuery = encodeURIComponent(query);
      
      console.log(`🔍 Foursquare: Searching for "${venueName}" at "${street}, ${city}"`);
      
      // Use the correct Foursquare Places API v3 endpoint
      // Note: Foursquare API v3 requires proper authentication and may have different endpoint structure
      const response = await axios.get(
        `https://api.foursquare.com/v3/places/search?query=${encodedQuery}&limit=1`,
        {
          headers: {
            'Authorization': this.foursquareApiKey,
            'Accept': 'application/json'
          }
        }
      );

      console.log(`🔍 Foursquare API response status: ${response.status}`);
      
      if (response.data && response.data.results && Array.isArray(response.data.results) && response.data.results.length > 0) {
        const venue = response.data.results[0];
        
        // Safely access venue properties
        if (!venue || typeof venue !== 'object') {
          console.log('⚠️ Foursquare: Invalid venue object in results');
          return null;
        }
        
        return {
          name: (venue.name) ? venue.name : venueName,
          address: (venue.location && venue.location.formatted_address) ? venue.location.formatted_address : `${street}, ${city}`,
          coordinates: (venue.geocodes && venue.geocodes.main) ? venue.geocodes.main : null,
          categories: (Array.isArray(venue.categories)) ? venue.categories : [],
          rating: venue.rating || null,
          price: venue.price || null,
          hours: venue.hours || null,
          photos: venue.photos || null,
          amenities: venue.amenities || null
        };
      } else {
        console.log('⚠️ Foursquare: No results found in response');
      }
    } catch (error) {
      // Enhanced error logging for Foursquare API
      const errorMessage = (error && error.message) ? error.message : 'Unknown error';
      const statusCode = (error && error.response && error.response.status) ? error.response.status : 'N/A';
      const statusText = (error && error.response && error.response.statusText) ? error.response.statusText : 'N/A';
      
      console.error(`❌ Foursquare API error: Request failed with status code ${statusCode}`);
      console.error(`❌ Foursquare error message: ${errorMessage}`);
      
      if (error.response) {
        console.error(`❌ Foursquare response status: ${statusCode} ${statusText}`);
        if (error.response.data) {
          console.error(`❌ Foursquare response data:`, JSON.stringify(error.response.data, null, 2));
        }
      }
      
      // 404 means endpoint doesn't exist - this is expected if Foursquare API structure changed
      if (statusCode === 404) {
        console.log('⚠️ Foursquare API endpoint returned 404 - endpoint may be incorrect or API structure changed');
      }
      
      // Don't throw, just return null to allow fallback to default data
    }
    
    return null;
  }

  /**
   * Find nearby transit stations using Google Places Nearby Search
   */
  async findNearbyTransitStations(lat, lng) {
    if (!this.googlePlacesApiKey) {
      console.log('🚇 Transit stations: API key not configured');
      return [];
    }

    try {
      console.log(`🚇 Searching for transit stations near ${lat}, ${lng}`);
      // Search for transit_station to get both tube and overground stations
      const response = await axios.get(
        `https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${lat},${lng}&radius=1500&type=transit_station&key=${this.googlePlacesApiKey}`
      );
      
      console.log(`🚇 Transit stations API response status: ${response?.data?.status || 'unknown'}`);
      console.log(`🚇 Transit stations found: ${response?.data?.results?.length || 0}`);

      if (response.data.results && response.data.results.length > 0) {
        console.log(`🚇 Raw station results before filtering: ${response.data.results.length}`);
        // Filter to only include actual train/tube stations (exclude car parks, roads, etc.)
        const stations = response.data.results
          .filter(station => {
            if (!station?.name) {
              console.log(`🚇 Excluding station - no name`);
              return false;
            }
            
            const name = station.name.toLowerCase();
            const types = station.types || [];
            
            // Exclude car parks, roads, bus stops, and other non-station places
            const excludedKeywords = ['car park', 'parking', 'road', 'street', 'avenue', 'way', 'lane', 'bus stop', 'bus station', 'fire station', 'theatre', 'theater', 'cinema', 'restaurant', 'cafe', 'shop', 'store', 'garden', 'park', '(stop', 'stop e)', 'stop f)', 'stop g)', 'stop h)', 'stop a)', 'stop b)', 'stop c)', 'stop d)'];
            if (excludedKeywords.some(keyword => name.includes(keyword))) {
              console.log(`🚇 Excluding '${station.name}' - contains excluded keyword`);
              return false;
            }
            
            // Exclude bus stops (check for bus-related types)
            if (types.some(type => type.includes('bus_station') || type.includes('bus_stop'))) {
              console.log(`🚇 Excluding '${station.name}' - bus stop type`);
              return false;
            }
            
            // Exclude if types indicate it's not a train/tube station
            const excludedTypes = ['parking', 'route', 'street_address', 'premise', 'establishment'];
            if (types.some(type => excludedTypes.some(excluded => type.toLowerCase().includes(excluded)))) {
              console.log(`🚇 Excluding '${station.name}' - excluded type`);
              return false;
            }
            
            // Include if types indicate it's a transit station
            const stationTypes = ['subway_station', 'train_station', 'transit_station', 'light_rail_station'];
            const isStationType = types.some(type => stationTypes.some(stType => type.includes(stType)));
            
            // Also include if name suggests it's a station
            const nameSuggestsStation = name.includes('station') || name.includes('tube') || 
                                       name.includes('underground') || name.includes('railway');
            
            // Include if it's a station type OR name suggests station
            const shouldInclude = isStationType || nameSuggestsStation;
            if (shouldInclude) {
              console.log(`🚇 Including '${station.name}' (types: ${types.join(', ')})`);
            } else {
              console.log(`🚇 Excluding '${station.name}' - not a station type`);
            }
            return shouldInclude;
          })
          .map(station => station.name)
          .filter(Boolean);
        
        console.log(`🚇 Stations after filtering: ${stations.length} - ${stations.join(', ')}`);
        
        // Remove duplicates and prefer names with "station" in them
        // Process stations in distance order and take the first 2 closest unique stations
        const stationInfo = {}; // baseName -> {name: best name, index: first occurrence index, hasStation: boolean}
        
        // Helper to get base name for deduplication
        const getBaseName = (name) => {
          return name.toLowerCase()
            .replace(/ station/g, '')
            .replace(/station/g, '')
            .trim();
        };
        
        // First pass: Process all stations to find the best version of each (preferring "station" in name)
        stations.forEach((station, index) => {
          const stationLower = station.toLowerCase();
          const baseName = getBaseName(station);
          const hasStation = stationLower.includes('station');
          
          if (stationInfo[baseName]) {
            // We've seen this base name before
            // If current station has "station" and existing doesn't, replace it
            if (hasStation && !stationInfo[baseName].hasStation) {
              console.log(`🚇 Updating '${stationInfo[baseName].name}' to '${station}' (preferring version with 'station', but keeping original distance order)`);
              stationInfo[baseName].name = station;
              stationInfo[baseName].hasStation = true;
            }
            // Otherwise keep the existing one (it came first, so it's closer)
          } else {
            // First time seeing this base name - record when we first saw it
            stationInfo[baseName] = { name: station, index: index, hasStation: hasStation };
          }
        });
        
        // Second pass: Add stations in distance order, using the best version of each
        // Sort by the original index (distance order) to get the 2 closest unique stations
        const sortedStations = Object.entries(stationInfo)
          .sort((a, b) => a[1].index - b[1].index)
          .slice(0, 2);
        
        const uniqueStations = sortedStations.map(([baseName, info]) => {
          console.log(`🚇 Adding station: '${info.name}' (baseName: '${baseName}', original index: ${info.index})`);
          return info.name;
        });
        
        // Take up to 2 stations (closest ones)
        const finalStations = uniqueStations.slice(0, 2);
        
        if (finalStations.length > 0) {
          console.log(`🚇 Found nearby transit stations: ${finalStations.join(', ')}`);
        }
        return finalStations;
      }
    } catch (error) {
      console.error('⚠️ Error finding nearby transit stations:', error.message);
    }

    return [];
  }

  /**
   * Format venue data from API response
   */
  formatVenueData(apiData, source, nearbyStations = []) {
    // More robust check - ensure apiData is an object
    if (!apiData || typeof apiData !== 'object' || apiData === null) {
      console.log('⚠️ formatVenueData: Invalid apiData provided:', {
        apiData: apiData,
        type: typeof apiData,
        isNull: apiData === null
      });
      // Return default data if apiData is null/undefined/not an object
      return this.getDefaultVenueData('');
    }
    
    console.log(`🏢 formatVenueData: source=${source}, nearbyStations=${nearbyStations.length} (${nearbyStations.join(', ')})`);
    
    try {
      const parkingInfo = this.generateParkingInfo(apiData, source, nearbyStations);
      const changingFacilities = this.generateChangingFacilities(apiData, source);
      
      return {
        parkingInfo,
        babyChangingFacilities: changingFacilities,
        accessibilityNotes: this.generateAccessibilityNotes(apiData, source),
        coordinates: (apiData.coordinates && typeof apiData.coordinates === 'object') ? apiData.coordinates : null,
        source: source,
        lastUpdated: new Date().toISOString()
      };
    } catch (error) {
      console.error('❌ Error in formatVenueData:', error.message);
      console.error('❌ apiData structure:', {
        hasApiData: !!apiData,
        apiDataType: typeof apiData,
        apiDataKeys: apiData ? Object.keys(apiData) : 'N/A'
      });
      // Return default data on error
      return this.getDefaultVenueData('');
    }
  }

  /**
   * Generate parking information based on venue data
   */
  generateParkingInfo(apiData, source, nearbyStations = []) {
    // More robust check - ensure apiData is an object
    if (!apiData || typeof apiData !== 'object' || apiData === null) {
      console.log('⚠️ generateParkingInfo: Invalid apiData provided');
      return "Street parking available nearby";
    }
    
    // Safely access properties with defensive checks
    const venueName = (apiData && typeof apiData === 'object' && apiData.name) ? String(apiData.name).toLowerCase() : '';
    const types = (apiData.types && Array.isArray(apiData.types)) ? apiData.types : ((apiData.categories && Array.isArray(apiData.categories)) ? apiData.categories : []);
    const address = (apiData && typeof apiData === 'object' && apiData.address) ? String(apiData.address).toLowerCase() : '';
    
    // Extract information from Google Places editorial summary and reviews
    if (source === 'google') {
      const editorialSummary = apiData.editorialSummary || '';
      const reviews = (apiData.reviews && Array.isArray(apiData.reviews)) ? apiData.reviews : [];
      
      console.log(`🚗 generateParkingInfo: editorialSummary length: ${String(editorialSummary).length}, reviews count: ${reviews.length}, nearbyStations: ${nearbyStations.length}`);
      
      // Build parking info from reviews
      const parkingKeywords = ['parking', 'car park', 'parking lot', 'street parking', 'pay and display', 'meter', 'parking bay', 'parking space'];
      const parkingReviews = reviews
        .filter(review => review && review.text)
        .map(review => review.text.toLowerCase())
        .filter(text => parkingKeywords.some(keyword => text.includes(keyword)))
        .slice(0, 3); // Take first 3 relevant reviews
      
      // Check editorial summary for parking info
      const summaryLower = String(editorialSummary).toLowerCase();
      const hasParkingInSummary = parkingKeywords.some(keyword => summaryLower.includes(keyword));
      
      console.log(`🚗 generateParkingInfo: parkingReviews found: ${parkingReviews.length}, hasParkingInSummary: ${hasParkingInSummary}`);
      
      // Special handling for theatres in London (often have limited parking)
      const isLondonTheatre = (venueName.includes('theatre') || venueName.includes('theater') || types.some(type => type.includes('theatre') || type.includes('theater'))) && 
                               (address.includes('london') || address.includes('city') || address.includes('central'));
      
      // Build detailed parking info if we have data OR if it's a London theatre with transit stations
      if (parkingReviews.length > 0 || hasParkingInSummary || (isLondonTheatre && nearbyStations.length > 0)) {
        let parkingText = '';
        
        // Check for on-site parking mentions
        const hasOnSiteParking = parkingReviews.some(text => 
          text.includes('on-site') || text.includes('on site') || text.includes('car park') || text.includes('parking lot')
        ) || summaryLower.includes('car park') || summaryLower.includes('parking lot');
        
        // Check for street parking mentions
        const hasStreetParking = parkingReviews.some(text => 
          text.includes('street parking') || text.includes('street park') || text.includes('pay and display') || text.includes('meter')
        ) || summaryLower.includes('street parking');
        
        if (hasOnSiteParking) {
          parkingText = "On-site parking available";
        } else if (hasStreetParking) {
          parkingText = "Limited street parking available - public transport recommended";
        } else if (isLondonTheatre) {
          parkingText = "Limited street parking available - public transport recommended";
        } else {
          parkingText = "Limited street parking available - public transport recommended";
        }
        
        // Add transit stations if available
        if (nearbyStations.length > 0) {
          parkingText += ` Nearest stations: ${nearbyStations.join(', ')}.`;
          console.log(`🚗 generateParkingInfo: Added transit stations to parking info`);
        } else {
          parkingText += " Check for pay-and-display bays nearby.";
        }
        
        console.log(`🚗 generateParkingInfo: Returning enhanced parking info: ${parkingText}`);
        return parkingText;
      }
    }
    
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
    
    // Special handling for theatres in London (often have limited parking)
    if ((venueName.includes('theatre') || venueName.includes('theater') || types.some(type => type.includes('theatre') || type.includes('theater'))) && 
        (address.includes('london') || address.includes('city') || address.includes('central'))) {
      let parkingText = "Limited street parking available - public transport recommended.";
      if (nearbyStations.length > 0) {
        parkingText += ` Nearest stations: ${nearbyStations.join(', ')}.`;
      } else {
        parkingText += " Check for pay-and-display bays nearby.";
      }
      return parkingText;
    }
    
    // Special handling for London locations
    if (address.includes('london') && (venueName.includes('gail') || types.some(type => type.includes('bakery')))) {
      let parkingText = "Limited street parking in Central London - public transport recommended";
      if (nearbyStations.length > 0) {
        parkingText += `. Nearest stations: ${nearbyStations.join(', ')}.`;
      } else {
        parkingText += ".";
      }
      return parkingText;
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
    if (!apiData) {
      return "Baby changing facilities available";
    }
    
    const types = apiData.types || apiData.categories || [];
    const venueName = apiData.name?.toLowerCase() || '';
    
    // Extract information from Google Places editorial summary and reviews
    if (source === 'google') {
      const editorialSummary = apiData.editorialSummary || '';
      const reviews = (apiData.reviews && Array.isArray(apiData.reviews)) ? apiData.reviews : [];
      
      // Build changing facilities info from editorial summary and reviews
      const summaryLower = String(editorialSummary).toLowerCase();
      const changingKeywords = ['baby changing', 'changing facilities', 'changing room', 'nappy changing', 'diaper changing', 'family-friendly', 'children', 'kids', 'family'];
      
      // Check if editorial summary mentions family-friendly features
      const hasFamilyFeatures = changingKeywords.some(keyword => summaryLower.includes(keyword));
      
      // Check reviews for changing facilities mentions
      const changingReviews = reviews
        .filter(review => review && review.text)
        .map(review => review.text.toLowerCase())
        .filter(text => changingKeywords.some(keyword => text.includes(keyword)))
        .slice(0, 2); // Take first 2 relevant reviews
      
      // Build detailed description if we have data
      if (hasFamilyFeatures || changingReviews.length > 0) {
        let changingText = '';
        
        // Check for specific mentions of baby changing facilities
        const hasChangingMention = summaryLower.includes('baby changing') || 
                                   summaryLower.includes('changing facilities') ||
                                   changingReviews.some(text => text.includes('baby changing') || text.includes('changing facilities'));
        
        // Build description based on editorial summary
        if (summaryLower.includes('children') || summaryLower.includes('kids') || summaryLower.includes('family')) {
          if (hasChangingMention) {
            changingText = String(editorialSummary).split('.')[0] + ' - baby changing facilities available in restrooms';
          } else {
            changingText = String(editorialSummary).split('.')[0] + ' - baby changing facilities available in restrooms';
          }
        } else {
          changingText = "Family-friendly venue - baby changing facilities available in restrooms";
        }
        
        return changingText;
      }
    }
    
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
    if (!apiData) {
      return "Accessibility information not available";
    }
    
    const types = apiData.types || apiData.categories || [];
    const address = (apiData && typeof apiData === 'object' && apiData.address) ? String(apiData.address).toLowerCase() : '';
    const venueName = (apiData && typeof apiData === 'object' && apiData.name) ? String(apiData.name).toLowerCase() : '';
    
    // Extract information from Google Places editorial summary and reviews
    if (source === 'google') {
      const editorialSummary = apiData.editorialSummary || '';
      const reviews = (apiData.reviews && Array.isArray(apiData.reviews)) ? apiData.reviews : [];
      
      // Build accessibility info from editorial summary and reviews
      const summaryLower = String(editorialSummary).toLowerCase();
      const accessibilityKeywords = ['wheelchair', 'accessible', 'accessibility', 'disabled access', 'ramp', 'elevator', 'lift'];
      
      // Check if editorial summary mentions accessibility
      const hasAccessibilityMention = accessibilityKeywords.some(keyword => summaryLower.includes(keyword));
      
      // Check reviews for accessibility mentions
      const accessibilityReviews = reviews
        .filter(review => review && review.text)
        .map(review => review.text.toLowerCase())
        .filter(text => accessibilityKeywords.some(keyword => text.includes(keyword)))
        .slice(0, 2); // Take first 2 relevant reviews
      
      // Build detailed description if we have data
      if (hasAccessibilityMention || accessibilityReviews.length > 0) {
        // Check for wheelchair accessible entrance
        if (apiData.wheelchairAccessibleEntrance === true) {
          return "Wheelchair accessible entrance confirmed - accessibility features available";
        } else if (apiData.wheelchairAccessibleEntrance === false) {
          return "Wheelchair accessibility may be limited - please contact venue for specific accessibility features";
        }
        
        // Build description based on venue type and location
        if (address.includes('london') || address.includes('city') || address.includes('central')) {
          return "Central London venue - accessibility varies by location. Contact venue for specific accessibility features and wheelchair access details.";
        } else {
          return "Accessibility features available - contact venue for specific details";
        }
      }
    }
    
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
   * Get coordinates for an address using Google Places API Text Search
   */
  async getCoordinatesForAddress(address) {
    if (!this.googlePlacesApiKey) {
      console.log('⚠️ Google Places API key not configured for geocoding');
      return null;
    }

    try {
      const addressString = `${address.street}, ${address.city}, ${address.postalCode}, ${address.country}`;
      const encodedAddress = encodeURIComponent(addressString);
      
      console.log(`📍 No coordinates from venue data, trying geocoding for: ${addressString}`);
      
      // Use Google Places Text Search API instead of Geocoding API
      const response = await axios.get(
        `https://maps.googleapis.com/maps/api/place/textsearch/json?query=${encodedAddress}&key=${this.googlePlacesApiKey}`,
        { timeout: 5000 } // 5 second timeout
      );

      if (response.data.results && response.data.results.length > 0) {
        const location = response.data.results[0].geometry.location;
        console.log(`📍 Found coordinates for ${addressString}: ${location.lat}, ${location.lng}`);
        return {
          latitude: location.lat,
          longitude: location.lng
        };
      }
      
      console.log(`📍 No coordinates found for: ${addressString}`);
    } catch (error) {
      if (error.code === 'ECONNABORTED') {
        console.log(`⏰ Geocoding timeout for: ${addressString}`);
      } else {
        console.error('❌ Geocoding API error:', error.message);
      }
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
