/**
 * YUGI Doability Scoring Service
 * 
 * Scores classes by how realistically "doable" they are for a specific parent,
 * factoring in logistics quality, distance, age match, schedule fit, 
 * availability, and rating signals.
 * 
 * Each factor produces a 0–1 sub-score. A weighted sum produces the final
 * doability score (0–100). Weights are configurable and should be tuned
 * as real behavioural data comes in (Phase 2).
 * 
 * Usage:
 *   const { scoreClasses } = require('./doabilityService');
 *   const rankedClasses = await scoreClasses(classes, parentContext, options);
 */

// ============================================================
// DEFAULT WEIGHTS — tune these as you gather attendance data
// ============================================================
const DEFAULT_WEIGHTS = {
  logistics:    0.30,  // Parking, baby changing, accessibility, transit
  distance:     0.25,  // How far the class is from the parent
  ageFit:       0.20,  // Does the class suit the parent's children's ages
  availability: 0.10,  // Spots remaining relative to capacity
  rating:       0.10,  // Average rating weighted by review count
  scheduleFit:  0.05,  // Does the class run on preferred days/times
};

// ============================================================
// MAIN ENTRY POINT
// ============================================================

/**
 * Score and rank an array of classes for a specific parent.
 *
 * @param {Array} classes       - Array of class documents (Mongoose lean objects or plain JS)
 * @param {Object} parentContext - Information about the requesting parent
 * @param {Object} [options]    - Override weights, limits, etc.
 * @returns {Array} Scored classes sorted by doability score descending
 *
 * parentContext shape:
 * {
 *   userId:       String,
 *   latitude:     Number | null,
 *   longitude:    Number | null,
 *   childrenAges: [Number],          // ages in years (e.g. [1, 3])
 *   preferredDays:  [String] | null, // e.g. ['monday', 'wednesday']
 *   preferredTimes: [String] | null, // e.g. ['morning', 'afternoon']
 * }
 */
async function scoreClasses(classes, parentContext = {}, options = {}) {
  const weights = { ...DEFAULT_WEIGHTS, ...options.weights };

  const scored = classes.map((classDoc) => {
    const scores = {
      logistics:    scoreLogistics(classDoc),
      distance:     scoreDistance(classDoc, parentContext),
      ageFit:       scoreAgeFit(classDoc, parentContext),
      availability: scoreAvailability(classDoc),
      rating:       scoreRating(classDoc),
      scheduleFit:  scoreScheduleFit(classDoc, parentContext),
    };

    // Weighted sum → 0–100
    let total = 0;
    for (const [factor, weight] of Object.entries(weights)) {
      total += (scores[factor] || 0) * weight;
    }
    const doabilityScore = Math.round(total * 100);

    // Build human-readable reasons (top contributing factors)
    const reasons = buildReasons(scores, classDoc, parentContext);

    // Build friction warnings (things that might cause problems)
    const frictionWarnings = buildFrictionWarnings(classDoc, parentContext);

    return {
      class: classDoc,
      doabilityScore,
      scores,        // sub-scores for debugging / transparency
      reasons,       // positive signals: ["5 min drive", "Perfect age match"]
      frictionWarnings, // friction flags: ["No baby changing facilities", "No parking info"]
    };
  });

  // Sort by doability score descending
  scored.sort((a, b) => b.doabilityScore - a.doabilityScore);

  return scored;
}

// ============================================================
// SCORING FUNCTIONS — each returns 0.0 to 1.0
// ============================================================

/**
 * LOGISTICS SCORE
 * 
 * The core of YUGI's value prop. Scores how well-documented and 
 * parent-friendly the venue logistics are.
 *
 * Sub-factors:
 * - Parking info exists and is substantive        (0.30)
 * - Baby changing facilities documented            (0.25)
 * - Accessibility notes provided                   (0.20)
 * - Transit info available                         (0.15)
 * - Location coordinates present                   (0.10)
 */
function scoreLogistics(classDoc) {
  const location = classDoc.location || {};
  const va       = classDoc.venueAccessibility || null;

  // ── Path A: Structured data from new Places API ──────────────────────────
  // Structured booleans are much more reliable than inferred text.
  // Scores are higher to reward venues with verified data.
  if (va) {
    let score = 0;

    // Pram/buggy accessible entrance — critical for parents with pushchairs
    if (va.pramAccessibleEntrance === true)       score += 0.22;
    else if (va.pramAccessibleEntrance === false)  score += 0.00; // confirmed inaccessible
    else                                           score += 0.04; // unknown

    // Baby changing
    if (va.hasBabyChanging === true)               score += 0.25;
    else if (va.hasBabyChanging === false)          score += 0.00;
    else                                           score += 0.04; // unknown

    // Parking type
    if (va.parkingType === 'free_lot' || va.parkingType === 'free_street') score += 0.20;
    else if (va.parkingType)                       score += 0.15; // paid/valet still useful
    else                                           score += 0.04; // unknown

    // Nearby transit stations with real distances
    if ((va.nearestStations?.length ?? 0) >= 2)   score += 0.15;
    else if ((va.nearestStations?.length ?? 0) === 1) score += 0.10;
    else                                           score += 0.02;

    // Accessible parking bay
    if (va.accessibleParking === true)             score += 0.05;

    // Coordinates (venue is mappable)
    const coords = location.coordinates || {};
    if (coords.latitude && coords.latitude !== 0)  score += 0.08;

    // Bonus: all three critical fields confirmed (data completeness)
    if (va.pramAccessibleEntrance !== null && va.hasBabyChanging !== null && va.parkingType !== null) {
      score += 0.05;
    }

    return Math.min(score, 1.0);
  }

  // ── Path B: Text-based scoring (legacy / Foursquare / default data) ──────
  // Capped at 0.75 to incentivise venues with structured data from the new API.
  let score = 0;

  const parkingInfo = (location.parkingInfo || '').trim();
  if (parkingInfo.length > 0) {
    const parkingQuality = Math.min(parkingInfo.length / 100, 0.75);
    score += 0.30 * parkingQuality;
    const parkingKeywords = ['free', 'on-site', 'nearby', 'spaces', 'street parking', 'car park', 'meter'];
    if (parkingKeywords.some(kw => parkingInfo.toLowerCase().includes(kw))) {
      score += 0.30 * 0.15;
    }
  }

  const babyChanging = (location.babyChangingFacilities || '').trim();
  if (babyChanging.length > 0) {
    score += 0.20; // Lower than structured-data path's 0.25
    const positiveTerms = ['available', 'yes', 'provided', 'dedicated', 'clean'];
    if (positiveTerms.some(t => babyChanging.toLowerCase().includes(t))) {
      score += 0.20 * 0.15;
    }
  }

  const accessNotes = (location.accessibilityNotes || classDoc.accessibilityNotes || '').trim();
  if (accessNotes.length > 0) {
    score += 0.15;
    const positiveAccess = ['pram', 'buggy', 'pushchair', 'wheelchair', 'step-free', 'lift', 'ramp', 'accessible'];
    if (positiveAccess.some(t => accessNotes.toLowerCase().includes(t))) {
      score += 0.15 * 0.25;
    }
  }

  const hasTransit = /station|bus stop|tube|underground|metro|train|tram/i.test(parkingInfo);
  if (hasTransit) score += 0.10;

  const coords = location.coordinates || {};
  if (coords.latitude && coords.longitude && coords.latitude !== 0) score += 0.10;

  return Math.min(score, 0.75); // cap — structured data scores higher
}

/**
 * DISTANCE SCORE
 * 
 * Closer classes score higher. Uses haversine formula.
 * If parent location is unknown, returns a neutral 0.5.
 *
 * Scoring curve:
 * - 0–2 km:   1.0 (walking distance)
 * - 2–5 km:   0.85
 * - 5–10 km:  0.65
 * - 10–20 km: 0.40
 * - 20+ km:   0.15
 */
function scoreDistance(classDoc, parentContext) {
  const { latitude: parentLat, longitude: parentLng } = parentContext;
  const coords = classDoc.location?.coordinates || {};
  const classLat = coords.latitude;
  const classLng = coords.longitude;

  // If we don't have both locations, return neutral score
  if (!parentLat || !parentLng || !classLat || !classLng || classLat === 0 || classLng === 0) {
    return 0.5;
  }

  const distanceKm = haversineDistance(parentLat, parentLng, classLat, classLng);

  // Store distance on the class doc for use in reasons
  classDoc._distanceKm = Math.round(distanceKm * 10) / 10;

  if (distanceKm <= 2) return 1.0;
  if (distanceKm <= 5) return 0.85;
  if (distanceKm <= 10) return 0.65;
  if (distanceKm <= 20) return 0.40;
  return 0.15;
}

/**
 * AGE FIT SCORE
 * 
 * Checks if the class age range matches the parent's children.
 * Uses the ageRange string field (e.g. "0-12 months", "1-3 years", "All ages").
 * 
 * Returns 1.0 for perfect match, 0.7 for close match, 0.3 for poor match.
 * If no children data, returns neutral 0.5.
 */
function scoreAgeFit(classDoc, parentContext) {
  const childrenAges = parentContext.childrenAges || [];
  if (childrenAges.length === 0) return 0.5;

  const ageRange = (classDoc.ageRange || '').toLowerCase().trim();
  if (!ageRange || ageRange === 'all ages') return 0.9; // "All ages" is almost always a fit

  // Parse age range — handles formats like:
  // "0-12 months", "1-3 years", "0-2", "newborn-6 months", "6 months - 2 years"
  const { minAge, maxAge } = parseAgeRange(ageRange);

  if (minAge === null || maxAge === null) return 0.5; // Can't parse, neutral

  // Check each child
  let bestMatch = 0;
  for (const childAge of childrenAges) {
    if (childAge >= minAge && childAge <= maxAge) {
      bestMatch = 1.0; // Perfect match
      break;
    }
    // Close match — child is within 1 year of range
    const distanceToRange = Math.min(
      Math.abs(childAge - minAge),
      Math.abs(childAge - maxAge)
    );
    if (distanceToRange <= 0.5) {
      bestMatch = Math.max(bestMatch, 0.8);
    } else if (distanceToRange <= 1) {
      bestMatch = Math.max(bestMatch, 0.6);
    } else {
      bestMatch = Math.max(bestMatch, 0.2);
    }
  }

  return bestMatch;
}

/**
 * AVAILABILITY SCORE
 * 
 * Classes with more available spots score slightly higher.
 * Nearly-full classes get a small penalty (harder to book).
 * Full classes get a heavy penalty.
 */
function scoreAvailability(classDoc) {
  const max = classDoc.maxCapacity || 1;
  const current = classDoc.currentBookings || 0;
  const available = max - current;
  const fillRate = current / max;

  if (available <= 0) return 0.05; // Full — still show it but rank low
  if (fillRate >= 0.9) return 0.4;  // Nearly full
  if (fillRate >= 0.7) return 0.7;  // Filling up
  return 1.0;                        // Plenty of room
}

/**
 * RATING SCORE
 * 
 * Combines average rating with review count for a confidence-weighted score.
 * A class with 4.5 stars from 20 reviews scores higher than 5.0 from 1 review.
 * New classes with no reviews get a neutral 0.5.
 */
function scoreRating(classDoc) {
  const avgRating = classDoc.averageRating || 0;
  const totalReviews = classDoc.totalReviews || 0;

  if (totalReviews === 0) return 0.5; // No reviews — neutral

  // Normalise rating to 0–1
  const normalisedRating = avgRating / 5.0;

  // Confidence factor — more reviews = more trustworthy
  // Uses logarithmic scale: confidence approaches 1.0 as reviews increase
  const confidence = Math.min(Math.log10(totalReviews + 1) / Math.log10(50), 1.0);

  // Bayesian-style blend: pull towards 0.6 (prior) when few reviews
  const prior = 0.6;
  const score = (confidence * normalisedRating) + ((1 - confidence) * prior);

  return score;
}

/**
 * SCHEDULE FIT SCORE
 * 
 * Scores how well the class schedule matches parent preferences.
 * If no preferences provided, returns neutral 0.5.
 */
function scoreScheduleFit(classDoc, parentContext) {
  const preferredDays = parentContext.preferredDays;
  const preferredTimes = parentContext.preferredTimes;

  if ((!preferredDays || preferredDays.length === 0) && 
      (!preferredTimes || preferredTimes.length === 0)) {
    return 0.5; // No preferences — neutral
  }

  let dayScore = 0.5;
  let timeScore = 0.5;

  // Day matching
  if (preferredDays && preferredDays.length > 0) {
    const classDays = (classDoc.recurringDays || []).map(d => d.toLowerCase());
    if (classDays.length > 0) {
      const matchingDays = classDays.filter(d => preferredDays.includes(d));
      dayScore = matchingDays.length > 0 ? 1.0 : 0.1;
    }
  }

  // Time matching (morning = before 12, afternoon = 12-17, evening = after 17)
  if (preferredTimes && preferredTimes.length > 0) {
    const timeSlots = classDoc.timeSlots || [];
    if (timeSlots.length > 0) {
      const classTimeOfDay = getTimeOfDay(timeSlots[0]?.startTime);
      timeScore = preferredTimes.includes(classTimeOfDay) ? 1.0 : 0.3;
    }
  }

  return (dayScore + timeScore) / 2;
}

// ============================================================
// REASON & FRICTION BUILDERS
// ============================================================

/**
 * Build human-readable reasons explaining WHY a class ranked well.
 * Returns the top 2–3 positive signals.
 */
function buildReasons(scores, classDoc, parentContext) {
  const reasons = [];

  // Distance reason
  if (classDoc._distanceKm !== undefined) {
    if (classDoc._distanceKm <= 2) {
      reasons.push({ factor: 'distance', text: `${classDoc._distanceKm} km away — walking distance`, priority: 1 });
    } else if (classDoc._distanceKm <= 5) {
      reasons.push({ factor: 'distance', text: `${classDoc._distanceKm} km away — short drive`, priority: 2 });
    } else if (classDoc._distanceKm <= 10) {
      reasons.push({ factor: 'distance', text: `${classDoc._distanceKm} km away`, priority: 3 });
    }
  }

  // Age fit reason
  if (scores.ageFit >= 0.9) {
    reasons.push({ factor: 'ageFit', text: 'Perfect age match for your child', priority: 1 });
  } else if (scores.ageFit >= 0.7) {
    reasons.push({ factor: 'ageFit', text: 'Good age match', priority: 2 });
  }

  // Logistics reasons
  if (scores.logistics >= 0.7) {
    reasons.push({ factor: 'logistics', text: 'Well-documented venue — parking, access & facilities verified', priority: 1 });
  } else if (scores.logistics >= 0.5) {
    reasons.push({ factor: 'logistics', text: 'Venue logistics partially verified', priority: 3 });
  }

  // Baby changing — prefer structured data
  const va = classDoc.venueAccessibility;
  if (va?.hasBabyChanging === true) {
    reasons.push({ factor: 'logistics', text: 'Baby changing facilities available', priority: 2 });
  } else if (!va) {
    const babyChanging = (classDoc.location?.babyChangingFacilities || '').trim();
    const positiveTerms = ['available', 'yes', 'provided', 'dedicated'];
    if (babyChanging.length > 0 && positiveTerms.some(t => babyChanging.toLowerCase().includes(t))) {
      reasons.push({ factor: 'logistics', text: 'Baby changing facilities available', priority: 2 });
    }
  }

  // Pram-accessible entrance (structured data only)
  if (va?.pramAccessibleEntrance === true) {
    reasons.push({ factor: 'logistics', text: 'Pram/buggy accessible entrance confirmed', priority: 2 });
  }

  // Weather forecast
  if (va?.weatherForecast) {
    reasons.push({ factor: 'logistics', text: `Weather: ${va.weatherForecast}`, priority: 3 });
  }

  // Rating reason
  if (classDoc.averageRating >= 4.5 && classDoc.totalReviews >= 5) {
    reasons.push({ factor: 'rating', text: `Highly rated (${classDoc.averageRating}★ from ${classDoc.totalReviews} reviews)`, priority: 1 });
  } else if (classDoc.averageRating >= 4.0 && classDoc.totalReviews >= 3) {
    reasons.push({ factor: 'rating', text: `Well reviewed (${classDoc.averageRating}★)`, priority: 3 });
  }

  // Availability reason
  const available = (classDoc.maxCapacity || 0) - (classDoc.currentBookings || 0);
  if (available > 0 && available <= 3) {
    reasons.push({ factor: 'availability', text: `Only ${available} spot${available === 1 ? '' : 's'} left`, priority: 1 });
  }

  // Schedule fit reason
  if (scores.scheduleFit >= 0.8) {
    reasons.push({ factor: 'scheduleFit', text: 'Fits your preferred schedule', priority: 2 });
  }

  // Sort by priority and take top 3
  reasons.sort((a, b) => a.priority - b.priority);
  return reasons.slice(0, 3).map(r => r.text);
}

/**
 * Build friction warnings — things that might cause problems on the day.
 * These are negative signals that the parent should know about.
 */
function buildFrictionWarnings(classDoc, parentContext) {
  const warnings = [];
  const location = classDoc.location || {};

  const va2 = classDoc.venueAccessibility;
  const hasYoungChild = (parentContext.childrenAges || []).some(age => age < 3);

  // Parking
  if (!va2 && !(location.parkingInfo || '').trim()) {
    warnings.push({ type: 'parking', text: 'No parking information available', severity: 'medium' });
  }

  // Baby changing
  if (va2) {
    if (va2.hasBabyChanging === false && hasYoungChild) {
      warnings.push({ type: 'babyChanging', text: 'No baby changing facilities at this venue', severity: 'high' });
    }
  } else if (hasYoungChild && !(location.babyChangingFacilities || '').trim()) {
    warnings.push({ type: 'babyChanging', text: 'No baby changing facilities listed', severity: 'high' });
  }

  // Accessibility / pram access
  if (va2) {
    if (va2.pramAccessibleEntrance === false) {
      warnings.push({ type: 'accessibility', text: 'Steps at entrance — not pram/buggy accessible', severity: 'high' });
    }
  } else if (!(location.accessibilityNotes || '').trim() && !(classDoc.accessibilityNotes || '').trim()) {
    warnings.push({ type: 'accessibility', text: 'No accessibility information — check pram access', severity: 'medium' });
  }

  // No coordinates (can't navigate)
  const coords = location.coordinates || {};
  if (!coords.latitude || !coords.longitude || coords.latitude === 0) {
    warnings.push({ type: 'location', text: 'Exact location not confirmed — check address', severity: 'low' });
  }

  // Nearly full
  const available = (classDoc.maxCapacity || 0) - (classDoc.currentBookings || 0);
  if (available === 1) {
    warnings.push({ type: 'capacity', text: 'Last spot available — book soon', severity: 'low' });
  } else if (available <= 0) {
    warnings.push({ type: 'capacity', text: 'Class is full', severity: 'high' });
  }

  // Distance warning
  if (classDoc._distanceKm && classDoc._distanceKm > 20) {
    warnings.push({ type: 'distance', text: `${classDoc._distanceKm} km away — long journey with little ones`, severity: 'medium' });
  }

  return warnings;
}

// ============================================================
// UTILITY FUNCTIONS
// ============================================================

/**
 * Haversine formula — distance between two lat/lng points in km.
 */
function haversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth's radius in km
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRad(deg) {
  return deg * (Math.PI / 180);
}

/**
 * Parse age range strings into { minAge, maxAge } in years.
 * 
 * Handles:
 * - "0-12 months"     → { minAge: 0, maxAge: 1 }
 * - "1-3 years"       → { minAge: 1, maxAge: 3 }
 * - "6 months-2 years"→ { minAge: 0.5, maxAge: 2 }
 * - "newborn-6 months"→ { minAge: 0, maxAge: 0.5 }
 * - "3+"              → { minAge: 3, maxAge: 12 }
 * - "All ages"        → { minAge: 0, maxAge: 18 }
 */
function parseAgeRange(ageRange) {
  const str = ageRange.toLowerCase().trim();

  if (str === 'all ages') return { minAge: 0, maxAge: 18 };

  // Try to find two numbers with optional units
  const pattern = /(\d+\.?\d*)\s*(months?|yrs?|years?|m)?\s*[-–to]+\s*(\d+\.?\d*)\s*(months?|yrs?|years?|m)?/i;
  const match = str.match(pattern);

  if (match) {
    let minVal = parseFloat(match[1]);
    let maxVal = parseFloat(match[3]);
    const minUnit = (match[2] || '').toLowerCase();
    const maxUnit = (match[4] || '').toLowerCase();

    // Convert months to years
    if (minUnit.startsWith('month') || minUnit === 'm') minVal = minVal / 12;
    if (maxUnit.startsWith('month') || maxUnit === 'm') maxVal = maxVal / 12;

    // If no units and values are small, assume years
    // If max is > 12 and no unit, likely months
    if (!maxUnit && maxVal > 12) maxVal = maxVal / 12;

    return { minAge: minVal, maxAge: maxVal };
  }

  // Handle "newborn" as 0
  if (str.includes('newborn')) {
    const numMatch = str.match(/(\d+\.?\d*)\s*(months?|yrs?|years?)?/);
    if (numMatch) {
      let maxVal = parseFloat(numMatch[1]);
      const unit = (numMatch[2] || '').toLowerCase();
      if (unit.startsWith('month')) maxVal = maxVal / 12;
      return { minAge: 0, maxAge: maxVal };
    }
    return { minAge: 0, maxAge: 1 };
  }

  // Handle "3+" style
  const plusMatch = str.match(/(\d+\.?\d*)\+/);
  if (plusMatch) {
    return { minAge: parseFloat(plusMatch[1]), maxAge: 12 };
  }

  return { minAge: null, maxAge: null };
}

/**
 * Determine time of day from a time string (e.g. "09:30", "14:00").
 */
function getTimeOfDay(timeStr) {
  if (!timeStr) return 'morning';
  const hour = parseInt(timeStr.split(':')[0], 10);
  if (isNaN(hour)) return 'morning';
  if (hour < 12) return 'morning';
  if (hour < 17) return 'afternoon';
  return 'evening';
}

// ============================================================
// EXPORTS
// ============================================================

module.exports = {
  scoreClasses,
  // Export individual scorers for testing
  scoreLogistics,
  scoreDistance,
  scoreAgeFit,
  scoreAvailability,
  scoreRating,
  scoreScheduleFit,
  // Export utilities for testing
  parseAgeRange,
  haversineDistance,
  buildReasons,
  buildFrictionWarnings,
  // Export weights for reference
  DEFAULT_WEIGHTS,
};
