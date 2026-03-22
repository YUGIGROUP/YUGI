const axios = require('axios');

// ─── Field masks for Places API (New) ────────────────────────────────────────

const SEARCH_FIELD_MASK  = 'places.id,places.displayName,places.formattedAddress,places.location';
const DETAILS_FIELD_MASK = [
  'id', 'displayName', 'formattedAddress', 'location',
  'accessibilityOptions.wheelchairAccessibleEntrance',
  'accessibilityOptions.wheelchairAccessibleRestroom',
  'accessibilityOptions.wheelchairAccessibleSeating',
  'accessibilityOptions.wheelchairAccessibleParking',
  'parkingOptions',
  'currentOpeningHours',
  'editorialSummary',
  'reviews',
].join(',');
const NEARBY_FIELD_MASK  = 'places.id,places.displayName,places.location,places.types';

// ─── Utility ─────────────────────────────────────────────────────────────────

function haversineMetres(lat1, lon1, lat2, lon2) {
  const R    = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a    = Math.sin(dLat / 2) ** 2
             + Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180)
             * Math.sin(dLon / 2) ** 2;
  return Math.round(R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
}

// ─── Service ──────────────────────────────────────────────────────────────────

class VenueDataService {
  constructor() {
    this.googleApiKey      = process.env.GOOGLE_PLACES_API_KEY;
    this.foursquareApiKey  = process.env.FOURSQUARE_API_KEY;
    this.openWeatherApiKey = process.env.OPENWEATHERMAP_API_KEY;
    this.cache             = new Map();
    this.cacheExpiry       = 24 * 60 * 60 * 1000; // 24 hours
    console.log(`🔑 VenueDataService: Google=${!!this.googleApiKey}, Foursquare=${!!this.foursquareApiKey}, Weather=${!!this.openWeatherApiKey}`);
  }

  // ─── Cache helpers ──────────────────────────────────────────────────────────

  _cacheKey(venueName, address) {
    return `${venueName}-${address.street}-${address.city}`.toLowerCase().trim();
  }

  _getCached(key) {
    const entry = this.cache.get(key);
    if (!entry) return null;
    if (Date.now() - entry.timestamp > this.cacheExpiry) { this.cache.delete(key); return null; }
    if (entry.data.source === 'default') { this.cache.delete(key); return null; }
    return entry.data;
  }

  _setCached(key, data) {
    if (data.source !== 'default') {
      this.cache.set(key, { data, timestamp: Date.now() });
    }
  }

  // Keep for backwards-compat: classes.js uses this to check if transit info is present
  hasTransitStations(venueData) {
    if (!venueData || !venueData.parkingInfo) return false;
    const p = venueData.parkingInfo.toLowerCase();
    return p.includes('station') || p.includes('tube') || p.includes('nearest stations:') || p.includes('public transport');
  }

  // ─── Main entry point ───────────────────────────────────────────────────────

  /**
   * @param {string}      venueName
   * @param {Object}      address      - { street, city, postalCode, country }
   * @param {boolean}     forceRefresh
   * @param {Date|null}   classTime    - Used to select the right weather forecast slot
   */
  async getRealVenueData(venueName, address, forceRefresh = false, classTime = null) {
    if (!venueName || !address || !address.street) {
      return this.getDefaultVenueData(venueName);
    }

    const key = this._cacheKey(venueName, address);

    if (!forceRefresh) {
      const cached = this._getCached(key);
      if (cached && this.hasTransitStations(cached)) {
        console.log(`📦 Using cached venue data for: ${venueName}`);
        return cached;
      }
    } else {
      console.log(`🔄 Force refresh for: ${venueName}`);
    }

    try {
      // ── Try Google Places (New API) ──────────────────────────────────────
      const googleData = await this._getGooglePlacesData(venueName, address);
      if (!googleData) console.log(`⚠️ Google Places returned no data for: ${venueName} — trying Foursquare`);
      if (googleData) {
        const lat = googleData.location && googleData.location.latitude;
        const lng = googleData.location && googleData.location.longitude;

        const [stations, weather] = await Promise.all([
          (lat && lng) ? this._findNearbyTransitStations(lat, lng) : Promise.resolve([]),
          (lat && lng) ? this._getWeatherForecast(lat, lng, classTime) : Promise.resolve(null),
        ]);

        const result = this._buildResult(googleData, 'google', stations, weather);
        this._setCached(key, result);
        return result;
      }

      // ── Foursquare fallback ──────────────────────────────────────────────
      const foursquareData = await this._getFoursquareData(venueName, address);
      if (!foursquareData) console.log(`⚠️ Foursquare returned no data for: ${venueName} — falling back to defaults`);
      if (foursquareData) {
        const result = this._buildResult(foursquareData, 'foursquare', [], null);
        this._setCached(key, result);
        return result;
      }
    } catch (error) {
      console.error('❌ Error fetching venue data:', error.message);
    }

    return this.getDefaultVenueData(venueName);
  }

  // ─── Google Places (New API) ────────────────────────────────────────────────

  async _getGooglePlacesData(venueName, address) {
    if (!this.googleApiKey) {
      console.log('⚠️ Google Places: GOOGLE_PLACES_API_KEY not set — skipping');
      return null;
    }
    try {
      const query = `${venueName} ${address.street} ${address.city}`.trim();

      // Step 1: Text search to find the place ID
      const searchResp = await axios.post(
        'https://places.googleapis.com/v1/places:searchText',
        { textQuery: query },
        { headers: { 'X-Goog-Api-Key': this.googleApiKey, 'X-Goog-FieldMask': SEARCH_FIELD_MASK } }
      );

      const places = searchResp.data && searchResp.data.places;
      if (!places || !places.length) {
        console.log(`⚠️ Google Places (New): No results for "${query}"`);
        return null;
      }

      const placeId = places[0].id;
      const name    = (places[0].displayName && places[0].displayName.text) || venueName;
      console.log(`✅ Google Places (New): Found "${name}" (${placeId})`);

      // Step 2: Fetch full place details
      const detailResp = await axios.get(
        `https://places.googleapis.com/v1/places/${placeId}`,
        { headers: { 'X-Goog-Api-Key': this.googleApiKey, 'X-Goog-FieldMask': DETAILS_FIELD_MASK } }
      );

      return (detailResp.data) || null;
    } catch (error) {
      const msg = (error.response && error.response.data && error.response.data.error && error.response.data.error.message) || error.message;
      console.error('❌ Google Places (New) error:', msg);
      return null;
    }
  }

  // Backwards-compat shim: classes.js calls this to get the formatted address
  async getGooglePlacesData(venueName, address) {
    const data = await this._getGooglePlacesData(venueName, address);
    if (!data) return null;
    return {
      address: data.formattedAddress || null,
      name:    (data.displayName && data.displayName.text) || venueName,
    };
  }

  // ─── Nearby transit stations ────────────────────────────────────────────────

  async _findNearbyTransitStations(lat, lng) {
    if (!this.googleApiKey) return [];
    try {
      const resp = await axios.post(
        'https://places.googleapis.com/v1/places:searchNearby',
        {
          includedTypes: [
            'transit_station', 'subway_station', 'train_station',
            'light_rail_station', 'bus_station',
          ],
          maxResultCount: 10,
          locationRestriction: {
            circle: { center: { latitude: lat, longitude: lng }, radius: 1500 },
          },
        },
        { headers: { 'X-Goog-Api-Key': this.googleApiKey, 'X-Goog-FieldMask': NEARBY_FIELD_MASK } }
      );

      const places = (resp.data && resp.data.places) || [];

      const stations = places
        .map(p => {
          const name     = (p.displayName && p.displayName.text) || '';
          const stLat    = p.location && p.location.latitude;
          const stLng    = p.location && p.location.longitude;
          const distance = (stLat && stLng) ? haversineMetres(lat, lng, stLat, stLng) : null;
          const types    = p.types || [];

          let type = 'bus';
          if (types.some(t => t === 'subway_station' || t === 'light_rail_station')) type = 'tube';
          else if (types.includes('train_station')) type = 'rail';

          return { name, distance, type };
        })
        .filter(s => {
          const n = s.name.toLowerCase();
          return s.name
            && !n.includes('bus stop')
            && !n.includes('(stop')
            && !n.includes('fire station');
        })
        .sort((a, b) => (a.distance !== null ? a.distance : 9999) - (b.distance !== null ? b.distance : 9999))
        .slice(0, 3); // 3 nearest

      console.log(`🚇 Found ${stations.length} nearby stations for (${lat}, ${lng})`);
      return stations;
    } catch (error) {
      const msg = (error.response && error.response.data && error.response.data.error && error.response.data.error.message) || error.message;
      console.error('❌ Nearby stations error:', msg);
      return [];
    }
  }

  // ─── Weather forecast ───────────────────────────────────────────────────────

  async _getWeatherForecast(lat, lng, classTime) {
    if (!this.openWeatherApiKey) {
      console.log('⚠️ OpenWeatherMap API key not configured (OPENWEATHERMAP_API_KEY)');
      return null;
    }
    try {
      const resp = await axios.get('https://api.openweathermap.org/data/2.5/forecast', {
        params: {
          lat,
          lon:   lng,
          appid: this.openWeatherApiKey,
          units: 'metric',
          cnt:   40, // 5 days of 3-hour slots
        },
      });

      const list = resp.data && resp.data.list;
      if (!list || !list.length) return null;

      // Find the forecast entry closest to classTime (or ~1 hr from now if not provided)
      const targetTs = classTime
        ? new Date(classTime).getTime() / 1000
        : Date.now() / 1000 + 3600;

      const entry = list.reduce((best, item) =>
        Math.abs(item.dt - targetTs) < Math.abs(best.dt - targetTs) ? item : best
      );

      const desc  = (entry.weather && entry.weather[0] && entry.weather[0].description) || 'unknown';
      const temp  = Math.round((entry.main && entry.main.temp) || 0);
      const rain3h = entry.rain && entry.rain['3h'];
      const isWet = (rain3h && rain3h > 0) || /rain|drizzle|shower/i.test(desc);

      let forecast = `${desc.charAt(0).toUpperCase() + desc.slice(1)}, ${temp}\u00b0C`;
      if (isWet) forecast += ' \u2014 bring rain cover for the pram';

      return forecast;
    } catch (error) {
      const msg = (error.response && error.response.data && error.response.data.message) || error.message;
      console.error('❌ Weather API error:', msg);
      return null;
    }
  }

  // ─── Foursquare fallback ────────────────────────────────────────────────────

  async _getFoursquareData(venueName, address) {
    if (!this.foursquareApiKey) return null;
    try {
      const query = `${venueName} ${address.street || ''} ${address.city || ''}`.trim();
      const resp  = await axios.get('https://api.foursquare.com/v3/places/search', {
        params:  { query, limit: 1 },
        headers: { Authorization: this.foursquareApiKey, Accept: 'application/json' },
      });

      const venue = resp.data && resp.data.results && resp.data.results[0];
      if (!venue) return null;

      // Normalise into the shape _buildResult understands
      return {
        displayName:          { text: venue.name || venueName },
        formattedAddress:     (venue.location && venue.location.formatted_address) || `${address.street}, ${address.city}`,
        location:             (venue.geocodes && venue.geocodes.main)
                                ? { latitude: venue.geocodes.main.lat, longitude: venue.geocodes.main.lng }
                                : null,
        accessibilityOptions: null, // Foursquare does not provide structured accessibility
        parkingOptions:       null,
        reviews:              [],
        editorialSummary:     null,
      };
    } catch (error) {
      console.error('❌ Foursquare error:', error.response && error.response.status, error.message);
      return null;
    }
  }

  // ─── Result builder ─────────────────────────────────────────────────────────

  _buildResult(placeData, source, stations, weather) {
    const accessibility = placeData.accessibilityOptions || {};
    const parking       = placeData.parkingOptions       || {};
    const reviews       = placeData.reviews              || [];
    const editorial     = (placeData.editorialSummary && placeData.editorialSummary.text) || '';
    const coords        = placeData.location;

    const hasBabyChanging = this._detectBabyChanging(reviews, editorial);
    const parkingType     = this._resolveParkingType(parking);

    const venueAccessibility = {
      pramAccessibleEntrance: (accessibility.wheelchairAccessibleEntrance !== undefined)
                                ? accessibility.wheelchairAccessibleEntrance : null,
      accessibleRestroom:     (accessibility.wheelchairAccessibleRestroom  !== undefined)
                                ? accessibility.wheelchairAccessibleRestroom  : null,
      accessibleSeating:      (accessibility.wheelchairAccessibleSeating   !== undefined)
                                ? accessibility.wheelchairAccessibleSeating   : null,
      accessibleParking:      (accessibility.wheelchairAccessibleParking   !== undefined)
                                ? accessibility.wheelchairAccessibleParking   : null,
      hasBabyChanging,
      parkingType,
      nearestStations:  stations,
      weatherForecast:  weather,
      lastVerified:     new Date(),
    };

    return {
      parkingInfo:            this._buildParkingInfo(parking, stations, venueAccessibility),
      babyChangingFacilities: this._buildBabyChangingText(hasBabyChanging),
      accessibilityNotes:     this._buildAccessibilityNotes(accessibility),
      coordinates:            coords
                                ? { latitude: coords.latitude, longitude: coords.longitude }
                                : null,
      formattedAddress:       placeData.formattedAddress || null,
      venueAccessibility,
      source,
      lastUpdated:            new Date().toISOString(),
    };
  }

  // ─── Text builders ──────────────────────────────────────────────────────────

  _buildAccessibilityNotes(accessibilityOptions) {
    const a = accessibilityOptions || {};

    if (a.wheelchairAccessibleEntrance === false) {
      return 'Step access only \u2014 may not be suitable for prams/buggies. Contact venue to confirm.';
    }

    const features = [];
    if (a.wheelchairAccessibleEntrance === true) features.push('pram/buggy accessible entrance');
    if (a.wheelchairAccessibleRestroom  === true) features.push('accessible restroom');
    if (a.wheelchairAccessibleSeating   === true) features.push('accessible seating');
    if (a.wheelchairAccessibleParking   === true) features.push('accessible parking');

    if (features.length > 0) {
      return `Pram/buggy friendly: ${features.join(', ')}.`;
    }

    return 'Accessibility not confirmed \u2014 contact venue for pram/buggy access details.';
  }

  _resolveParkingType(parkingOptions) {
    const p = parkingOptions || {};
    if (p.freeParkingLot    || p.freeGarageParking)  return 'free_lot';
    if (p.paidParkingLot    || p.paidGarageParking)  return 'paid_lot';
    if (p.freeStreetParking)                          return 'free_street';
    if (p.paidStreetParking)                          return 'paid_street';
    if (p.valetParking)                               return 'valet';
    return null;
  }

  _buildParkingInfo(parkingOptions, stations, venueAccessibility) {
    const p     = parkingOptions || {};
    const parts = [];

    if      (p.freeParkingLot   || p.freeGarageParking)  parts.push('Free parking available on-site.');
    else if (p.paidParkingLot   || p.paidGarageParking)  parts.push('Paid parking available on-site.');
    else if (p.freeStreetParking)                         parts.push('Free street parking available.');
    else if (p.paidStreetParking)                         parts.push('Paid street parking nearby (check restrictions).');
    else if (p.valetParking)                              parts.push('Valet parking available.');
    else                                                  parts.push('Street parking available nearby.');

    if (venueAccessibility && venueAccessibility.accessibleParking === true) {
      parts.push('Accessible parking bays available.');
    }

    if (stations && stations.length > 0) {
      const list = stations
        .map(s => s.distance ? `${s.name} (${s.distance}m)` : s.name)
        .join(', ');
      parts.push(`Nearest stations: ${list}.`);
    }

    return parts.join(' ');
  }

  _detectBabyChanging(reviews, editorial) {
    const text = [
      editorial,
      ...reviews.map(r => (r.text && r.text.text) || (typeof r.text === 'string' ? r.text : '') || ''),
    ].join(' ').toLowerCase();

    const negative = ['no baby changing', 'no changing', "doesn't have changing", 'no nappy'];
    const positive = ['baby changing', 'nappy changing', 'diaper changing', 'changing facilities', 'changing room', 'family bathroom'];
    const family   = ['family-friendly', 'child-friendly', 'family friendly', 'child friendly', 'toddler', 'baby'];

    if (negative.some(t => text.includes(t))) return false;
    if (positive.some(t => text.includes(t))) return true;
    if (family.some(t => text.includes(t)))   return true;
    return null; // unknown
  }

  _buildBabyChangingText(hasBabyChanging) {
    if (hasBabyChanging === true)  return 'Baby changing facilities available.';
    if (hasBabyChanging === false) return 'No baby changing facilities confirmed \u2014 check with venue.';
    return 'Baby changing facilities not confirmed \u2014 contact venue.';
  }

  // ─── Geocoding ──────────────────────────────────────────────────────────────

  async getCoordinatesForAddress(address) {
    if (!this.googleApiKey) return null;
    try {
      const query = `${address.street}, ${address.city}, ${address.postalCode || ''}, ${address.country || 'UK'}`.trim();
      const resp  = await axios.post(
        'https://places.googleapis.com/v1/places:searchText',
        { textQuery: query },
        {
          headers: { 'X-Goog-Api-Key': this.googleApiKey, 'X-Goog-FieldMask': 'places.location' },
          timeout: 5000,
        }
      );
      const loc = resp.data && resp.data.places && resp.data.places[0] && resp.data.places[0].location;
      if (loc) {
        console.log(`📍 Geocoded: ${query} \u2192 ${loc.latitude}, ${loc.longitude}`);
        return { latitude: loc.latitude, longitude: loc.longitude };
      }
    } catch (error) {
      console.error('❌ Geocoding error:', error.message);
    }
    return null;
  }

  // ─── Default fallback ───────────────────────────────────────────────────────

  getDefaultVenueData(venueName) {
    console.log(`🏢 Using default venue data for: ${venueName}`);
    const name = (venueName || '').toLowerCase();

    let parkingInfo            = 'Street parking available nearby.';
    let babyChangingFacilities = 'Baby changing facilities not confirmed \u2014 contact venue.';
    let accessibilityNotes     = 'Accessibility not confirmed \u2014 contact venue for pram/buggy access details.';

    if (name.includes('community') || name.includes('centre') || name.includes('center')
        || name.includes('church')  || name.includes('hall')) {
      parkingInfo            = 'Free parking available on-site.';
      babyChangingFacilities = 'Baby changing facilities available.';
      accessibilityNotes     = 'Pram/buggy friendly: pram/buggy accessible entrance.';
    } else if (name.includes('library') || name.includes('museum')) {
      parkingInfo            = 'Limited parking \u2014 street parking recommended.';
      babyChangingFacilities = 'Baby changing facilities available.';
      accessibilityNotes     = 'Pram/buggy friendly: accessible entrance, accessible restroom.';
    } else if (name.includes('park') || name.includes('garden')) {
      parkingInfo            = 'Free parking available.';
      babyChangingFacilities = 'Portable changing facilities recommended.';
      accessibilityNotes     = 'Partially accessible \u2014 some areas may have uneven terrain.';
    }

    return {
      parkingInfo,
      babyChangingFacilities,
      accessibilityNotes,
      coordinates:        null,
      formattedAddress:   null,
      venueAccessibility: null,
      source:             'default',
      lastUpdated:        new Date().toISOString(),
    };
  }
}

module.exports = new VenueDataService();
