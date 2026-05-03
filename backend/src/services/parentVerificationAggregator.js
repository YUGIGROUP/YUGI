const VenueFactFeedback = require('../models/VenueFactFeedback');
const VenueEnrichment   = require('../models/VenueEnrichment');

const PARENT_VERIFIED_THRESHOLD = 5;        // confirmations needed for parent_verified tier
const DISPUTED_THRESHOLD = 3;                // recent disputes that trigger disputed tier
const RECENT_WINDOW_DAYS = 30;

const PER_FACT_VERIFIED_THRESHOLD = 3;   // confirmations needed for per-fact parent_verified
const PER_FACT_DISPUTED_THRESHOLD = 2;   // recent disputes that flip a fact to disputed
const ROLLUP_VERIFIED_RATIO = 0.5;       // fraction of facts that need to be parent_verified for top-level parent_verified

/**
 * Determine the confidence tier for a single fact based on its event counts
 * and the existing AI confidence for that fact's section.
 *
 * @param {{confirmations: number, disputes: number, recentDisputes: number}} entry
 * @param {string|undefined} aiConfidence - 'high' | 'medium' | 'low' | null
 * @returns {string} - 'parent_verified' | 'disputed' | 'ai_high' | 'ai_medium' | 'ai_low'
 */
function determineFactTier(entry, aiConfidence) {
  if (entry.recentDisputes >= PER_FACT_DISPUTED_THRESHOLD) return 'disputed';
  if (entry.confirmations >= PER_FACT_VERIFIED_THRESHOLD && entry.recentDisputes === 0) return 'parent_verified';
  if (aiConfidence === 'high') return 'ai_high';
  if (aiConfidence === 'medium') return 'ai_medium';
  if (aiConfidence === 'low') return 'ai_low';
  return 'ai_medium';
}

async function aggregateOne(placeId) {
  // 1. Fetch all events for this placeId
  const events = await VenueFactFeedback.find({ placeId }).lean();
  if (events.length === 0) return { placeId, skipped: true, reason: 'no events' };

  // 2. Compute totals
  const totalConfirmations = events.filter(e => e.agreed === true).length;
  const totalDisputes = events.filter(e => e.agreed === false).length;

  // 3. Compute recent disputes (last 30 days)
  const cutoff = new Date(Date.now() - RECENT_WINDOW_DAYS * 24 * 60 * 60 * 1000);
  const recentDisputes30d = events.filter(e => e.agreed === false && e.createdAt >= cutoff).length;

  // 4. Build factSummary as a plain object (Mongoose Map will accept this)
  //    Group events by factPath, skip "overall" path (it's a comment-only entry)
  const factSummary = {};
  for (const evt of events) {
    if (evt.factPath === 'overall') continue;
    if (!factSummary[evt.factPath]) {
      factSummary[evt.factPath] = {
        confirmations: 0,
        disputes: 0,
        recentDisputes: 0,
        lastConfirmed: null,
        lastDisputed: null,
      };
    }
    const entry = factSummary[evt.factPath];
    if (evt.agreed === true) {
      entry.confirmations += 1;
      if (!entry.lastConfirmed || evt.createdAt > entry.lastConfirmed) entry.lastConfirmed = evt.createdAt;
    } else {
      entry.disputes += 1;
      if (evt.createdAt >= cutoff) entry.recentDisputes += 1;
      if (!entry.lastDisputed || evt.createdAt > entry.lastDisputed) entry.lastDisputed = evt.createdAt;
    }
  }

  const enrichment = await VenueEnrichment.findOne({ placeId }).lean();
  if (!enrichment) return { placeId, skipped: true, reason: 'no enrichment record' };

  for (const factPath of Object.keys(factSummary)) {
    const section = factPath.split('.')[0];
    const aiConfidence = enrichment.enrichedData?.[section]?.confidence;
    factSummary[factPath].confidenceTier = determineFactTier(factSummary[factPath], aiConfidence);
  }

  // 5. Compute top-level confidenceTier as rollup over per-fact tiers
  const factTiers = Object.values(factSummary).map(e => e.confidenceTier);
  let confidenceTier;

  if (factTiers.length === 0) {
    // No per-fact events (shouldn't happen if we got here, but defensive)
    confidenceTier = 'ai_medium';
  } else {
    const verifiedCount = factTiers.filter(t => t === 'parent_verified').length;
    const disputedCount = factTiers.filter(t => t === 'disputed').length;
    const verifiedRatio = verifiedCount / factTiers.length;

    if (disputedCount > 0 && verifiedCount > 0) {
      confidenceTier = 'mixed';
    } else if (disputedCount > 0) {
      confidenceTier = 'disputed';
    } else if (verifiedRatio >= ROLLUP_VERIFIED_RATIO) {
      confidenceTier = 'parent_verified';
    } else {
      // Some facts confirmed but not enough for verified rollup — inherit highest AI tier across the venue
      const tiers = [
        enrichment.enrichedData?.parking?.confidence,
        enrichment.enrichedData?.babyChanging?.confidence,
        enrichment.enrichedData?.pramAccess?.confidence,
        enrichment.enrichedData?.publicTransport?.confidence,
      ].filter(Boolean);
      if (tiers.includes('high')) confidenceTier = 'ai_high';
      else if (tiers.includes('medium')) confidenceTier = 'ai_medium';
      else if (tiers.includes('low')) confidenceTier = 'ai_low';
      else confidenceTier = 'ai_medium';
    }
  }

  // 6. Build the parentVerification block
  const parentVerification = {
    totalConfirmations,
    totalDisputes,
    recentDisputes30d,
    factSummary,
    confidenceTier,
    lastAggregatedAt: new Date(),
  };

  // 7. Update the VenueEnrichment record
  const result = await VenueEnrichment.updateOne(
    { placeId },
    { $set: { 'enrichedData.parentVerification': parentVerification } }
  );

  return {
    placeId,
    success: true,
    matched: result.matchedCount,
    modified: result.modifiedCount,
    confidenceTier,
    totalConfirmations,
    totalDisputes,
  };
}

async function aggregateAll() {
  const startedAt = Date.now();
  const distinctPlaceIds = await VenueFactFeedback.distinct('placeId');

  const results = [];
  for (const placeId of distinctPlaceIds) {
    try {
      const r = await aggregateOne(placeId);
      results.push(r);
    } catch (err) {
      console.error(`Aggregation failed for ${placeId}:`, err.message);
      results.push({ placeId, error: err.message });
    }
  }

  const elapsedMs = Date.now() - startedAt;
  const successes = results.filter(r => r.success).length;
  const skipped = results.filter(r => r.skipped).length;
  const errored = results.filter(r => r.error).length;

  console.log(`📊 Parent verification aggregation: ${successes} updated, ${skipped} skipped, ${errored} errored, ${elapsedMs}ms total`);

  return { startedAt, elapsedMs, total: results.length, successes, skipped, errored, results };
}

module.exports = { aggregateAll, aggregateOne };
