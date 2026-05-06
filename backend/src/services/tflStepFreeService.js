const axios = require('axios');
const StationAccessibility = require('../models/StationAccessibility');

const TFL_BASE = 'https://api.tfl.gov.uk';

/** TfL HTTP timeout — avoids wedging venue analysis if TfL is slow */
const REQUEST_TIMEOUT_MS = 8000;

const CACHE_MS_SUCCESS = 30 * 24 * 60 * 60 * 1000;
const CACHE_MS_ERROR   = 60 * 60 * 1000;
/** Station absent / unusable match — cache longer than API-errors but bounded */
const CACHE_MS_NO_MATCH = 30 * 24 * 60 * 60 * 1000;

function normaliseSearchAlias(stationName) {
  if (!stationName || typeof stationName !== 'string') return '';
  let s = stationName.trim().toLowerCase().replace(/\s+/g, ' ');
  const cutSuffix = (suffix) => {
    if (s.endsWith(suffix)) {
      s = s.slice(0, -suffix.length).trim();
    }
  };
  cutSuffix('underground station');
  cutSuffix('tube station');
  cutSuffix('dlr station');
  return s.replace(/\s+/g, ' ').trim();
}

function facilityNumber(stopPoint, facilityKey) {
  const props = stopPoint.additionalProperties || [];
  const row = props.find((p) => p.category === 'Facility' && p.key === facilityKey);
  if (!row || row.value == null || row.value === '') return 0;
  const n = parseInt(String(row.value).replace(/[^\d-]/g, ''), 10);
  return Number.isFinite(n) ? Math.max(0, n) : 0;
}

function extractAccessibilityPairs(stopPoint) {
  const props = stopPoint.additionalProperties || [];
  return props
    .filter((p) => p.category === 'Accessibility')
    .map((p) => ({ key: p.key, value: String(p.value ?? '') }));
}

/** TfL GET often resolves interchange hubs under metro ids — unwrap embedded metro child with tube mode */
function extractTubeMetroPayload(stopPointDetail) {
  if (!stopPointDetail) return null;

  const modesTube = (stopPointDetail.modes || []).includes('tube');

  if (stopPointDetail.stopType === 'NaptanMetroStation' && modesTube) {
    return {
      metro:       stopPointDetail,
      hubNaptanId: stopPointDetail.hubNaptanCode || null,
    };
  }

  const idStr = String(stopPointDetail.id || stopPointDetail.naptanId || '');

  if (stopPointDetail.stopType === 'TransportInterchange' && idStr.startsWith('HUB')) {
    const children = stopPointDetail.children || [];
    const metro = children.find(
      (c) => c.stopType === 'NaptanMetroStation' && (c.modes || []).includes('tube')
    );
    if (metro) return { metro, hubNaptanId: stopPointDetail.id || idStr };
  }

  if (stopPointDetail.children && stopPointDetail.children.length) {
    const metro = stopPointDetail.children.find(
      (c) => c.stopType === 'NaptanMetroStation' && (c.modes || []).includes('tube')
    );
    if (metro) {
      const hubId =
        stopPointDetail.stopType === 'TransportInterchange'
          ? stopPointDetail.id
          : stopPointDetail.hubNaptanCode || null;
      return { metro, hubNaptanId: hubId };
    }
  }

  return null;
}

function matchSearchCandidate(match) {
  if (!match || !match.id) return false;
  const st = match.stopType || match.placeType;
  if (st === 'NaptanMetroStation') return true;
  if (st === 'TransportInterchange' && String(match.id).startsWith('HUB')) return true;
  return false;
}

async function fetchStopPoint(id, apiKey) {
  const url = `${TFL_BASE}/StopPoint/${encodeURIComponent(id)}`;
  const { data } = await axios.get(url, {
    params:  { app_key: apiKey },
    timeout: REQUEST_TIMEOUT_MS,
  });
  return data;
}

async function fetchSearch(alias, apiKey) {
  const url = `${TFL_BASE}/StopPoint/Search/${encodeURIComponent(alias)}`;
  const { data } = await axios.get(url, {
    params:  { modes: 'tube', app_key: apiKey },
    timeout: REQUEST_TIMEOUT_MS,
  });
  return data;
}

async function saveLookupFailure(alias, googleStationName, opts = {}) {
  const ttlMs = opts.ttlMs ?? CACHE_MS_ERROR;
  const now = new Date();
  await StationAccessibility.findOneAndUpdate(
    { searchAlias: alias },
    {
      $set: {
        stationName:           googleStationName,
        searchAlias:           alias,
        lookupFailed:          true,
        resolvedStepFree:      'unknown',
        accessViaLift:         null,
        rawAccessibilityPairs: [],
        liftCount:             0,
        escalatorCount:        0,
        stopType:              null,
        hubNaptanId:           null,
        fetchedAt:             now,
        cacheExpiresAt:        new Date(Date.now() + ttlMs),
      },
      $unset: { naptanId: '' },
    },
    { upsert: true, setDefaultsOnInsert: true }
  );
}

async function saveResolved(alias, googleStationName, resolved) {
  const { metro, hubNaptanId } = resolved;
  const rawPairs = extractAccessibilityPairs(metro);
  const avRow = rawPairs.find((p) => p.key === 'AccessViaLift');
  const accessViaLift = avRow ? avRow.value : null;
  const resolvedStepFree = accessViaLift === 'Yes' ? 'confirmed' : 'unknown';

  const naptanId = metro.naptanId || metro.id || null;
  const now = new Date();

  try {
    await StationAccessibility.findOneAndUpdate(
      { searchAlias: alias },
      {
        $set: {
          stationName:           metro.commonName || googleStationName,
          searchAlias:           alias,
          naptanId,
          hubNaptanId:           hubNaptanId || null,
          stopType:              metro.stopType || 'NaptanMetroStation',
          accessViaLift,
          liftCount:             facilityNumber(metro, 'Lifts'),
          escalatorCount:        facilityNumber(metro, 'Escalators'),
          rawAccessibilityPairs: rawPairs,
          resolvedStepFree,
          lookupFailed:          false,
          fetchedAt:             now,
          cacheExpiresAt:        new Date(Date.now() + CACHE_MS_SUCCESS),
        },
      },
      { upsert: true, setDefaultsOnInsert: true }
    );
  } catch (err) {
    /* Rare: same NaPTAN cached under another searchAlias — unique index on naptanId */
    if (err && err.code === 11000) {
      console.warn(`🚇 TfL: cache persist skipped (duplicate key) alias="${alias}"`, err.message);
    } else {
      throw err;
    }
  }

  return { resolvedStepFree, accessViaLift, naptanId };
}

/**
 * Lazy TfL step-free lookup with Mongo cache keyed by normalised search alias.
 * Failures are cached briefly to avoid hammering TfL; successes use a 30-day TTL.
 */
async function getStepFreeForStation(stationName) {
  const alias = normaliseSearchAlias(stationName);
  const apiKey = process.env.TFL_APP_KEY;

  if (!alias) {
    console.log('🚇 TfL: empty search alias after normalisation — skipping');
    return { resolvedStepFree: 'unknown' };
  }

  if (!apiKey) {
    console.log('🚇 TfL: TFL_APP_KEY not configured — skipping enrichment');
    return { resolvedStepFree: 'unknown' };
  }

  try {
    const cached = await StationAccessibility.findOne({
      searchAlias:    alias,
      cacheExpiresAt: { $gt: new Date() },
    }).lean();

    if (cached) {
      if (cached.lookupFailed) {
        console.log(`🚇 TfL: cache hit (lookupFailed, TTL valid) alias="${alias}"`);
        return { resolvedStepFree: 'unknown' };
      }
      console.log(`🚇 TfL: cache hit alias="${alias}" resolved=${cached.resolvedStepFree}`);
      return {
        resolvedStepFree: cached.resolvedStepFree,
        accessViaLift:    cached.accessViaLift,
        naptanId:         cached.naptanId,
      };
    }

    console.log(`🚇 TfL: cache miss alias="${alias}"`);

    let searchPayload;
    try {
      console.log(`🚇 TfL: StopPoint/Search query="${alias}" modes=tube`);
      searchPayload = await fetchSearch(alias, apiKey);
    } catch (e) {
      console.error('🚇 TfL: search request failed', e.message || e);
      await saveLookupFailure(alias, stationName, { ttlMs: CACHE_MS_ERROR });
      return { resolvedStepFree: 'unknown' };
    }

    const matches = searchPayload.matches || [];
    console.log(`🚇 TfL: search returned ${matches.length} match(es) for "${alias}"`);

    const orderedIds = [];

    for (const m of matches) {
      if (matchSearchCandidate(m) && m.id) orderedIds.push(m.id);
    }
    for (const m of matches) {
      if (m.id && !orderedIds.includes(m.id)) orderedIds.push(m.id);
    }

    let resolved = null;

    for (const id of orderedIds.slice(0, 15)) {
      let detail;
      try {
        detail = await fetchStopPoint(id, apiKey);
      } catch (e) {
        console.error(`🚇 TfL: StopPoint/${id} failed`, e.message || e);
        continue;
      }
      resolved = extractTubeMetroPayload(detail);
      if (resolved) break;
    }

    if (!resolved) {
      console.log(`🚇 TfL: no usable tube metro for alias="${alias}"`);
      await saveLookupFailure(alias, stationName, { ttlMs: CACHE_MS_NO_MATCH });
      return { resolvedStepFree: 'unknown' };
    }

    const { resolvedStepFree, accessViaLift, naptanId } = await saveResolved(
      alias,
      stationName,
      resolved
    );
    console.log(
      `🚇 TfL: accessibility resolved alias="${alias}" accessViaLift=${accessViaLift ?? 'null'} → ${resolvedStepFree}`
    );
    return { resolvedStepFree, accessViaLift, naptanId };
  } catch (err) {
    console.error('🚇 TfL: unexpected error', err.message || err);
    try {
      await saveLookupFailure(alias, stationName, { ttlMs: CACHE_MS_ERROR });
    } catch (_persistErr) {
      /* ignore secondary persistence failures */
    }
    return { resolvedStepFree: 'unknown' };
  }
}

module.exports = {
  getStepFreeForStation,
  normaliseSearchAlias,
};
