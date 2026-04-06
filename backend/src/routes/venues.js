const express         = require('express');
const router          = express.Router();
const Anthropic       = require('@anthropic-ai/sdk');
const VenueEnrichment = require('../models/VenueEnrichment');
const { protect } = require('../middleware/auth');

// ─── Rate limiter: max 50 Claude enrichments per hour globally ────────────────

let hourlyCount   = 0;
let hourlyResetAt = Date.now() + 60 * 60 * 1000;

function checkRateLimit() {
  const now = Date.now();
  if (now >= hourlyResetAt) {
    hourlyCount   = 0;
    hourlyResetAt = now + 60 * 60 * 1000;
  }
  if (hourlyCount >= 50) return false;
  hourlyCount++;
  return true;
}

// ─── Anthropic client ─────────────────────────────────────────────────────────

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

const SYSTEM_PROMPT = `You are a venue data extraction tool. Your sole output must be a single raw JSON object.

CRITICAL: Return ONLY raw JSON with no preamble, no markdown, no explanation — just the JSON object starting with { and ending with }. Do not write anything before or after the JSON. Do not use backticks or code fences.

Search the web to find parent-relevant venue information. Focus on:
1. Parking: total spaces, car park names, type (multi-storey/surface/underground), Blue Badge bays, parent & child bays, cost/pricing, ticketless/ANPR, EV charging
2. Baby changing: available or not, exact location within venue, details
3. Pram/step-free access: step-free access, lifts, details
4. Public transport: nearest station, walking time, bus routes
5. Any other parent-relevant logistics (feeding rooms, family lifts, buggy parks, etc.)

Output schema (use null for unknown values, never empty strings for unknowns):
{
  "parking": {
    "totalSpaces": <integer or null>,
    "carParkNames": [<strings>],
    "type": "<multi-storey|surface|underground|mixed|null>",
    "blueBadgeBays": <integer or null>,
    "parentBays": <integer or null>,
    "costInfo": "<string or null>",
    "ticketless": <true|false|null>,
    "evCharging": <true|false|null>
  },
  "babyChanging": {
    "available": <true|false|null>,
    "location": "<string or null>",
    "details": "<string or null>"
  },
  "pramAccess": {
    "stepFreeAccess": <true|false|null>,
    "liftAvailable": <true|false|null>,
    "details": "<string or null>"
  },
  "publicTransport": {
    "nearestStation": "<string or null>",
    "walkingTime": "<string or null>",
    "busRoutes": [<strings>]
  },
  "additionalNotes": "<string or null>",
  "sources": [<URL strings>]
}`;

// ─── Extract the JSON object from a Claude response string ────────────────────
// Handles: preamble text before {, markdown code fences, trailing text after }

function extractJson(raw) {
  // Find the first { and last } to slice out just the JSON object
  const start = raw.indexOf('{');
  const end   = raw.lastIndexOf('}');
  if (start === -1 || end === -1 || end < start) return null;
  return raw.slice(start, end + 1);
}

// ─── GET /api/venues/:placeId/enrichment ─────────────────────────────────────

router.get('/:placeId/enrichment', protect, async (req, res) => {
  const { placeId } = req.params;
  const venueName   = req.query.venueName || placeId;

  try {
    // 1. Check MongoDB cache — return immediately if not expired
    const cached = await VenueEnrichment.findOne({
      placeId,
      expiresAt: { $gt: new Date() },
    });

    if (cached) {
      console.log(`📦 Cache hit for venue enrichment: ${venueName} (${placeId})`);
      return res.json({
        placeId:      cached.placeId,
        venueName:    cached.venueName,
        enrichedData: cached.enrichedData,
        sources:      cached.sources,
        confidence:   cached.confidence,
        cachedAt:     cached.createdAt,
      });
    }

    // 2. Global rate limit: max 50 enrichments per hour
    if (!checkRateLimit()) {
      console.log(`⚠️ Venue enrichment rate limit reached`);
      return res.status(429).json({ error: 'Rate limit reached — try again later', enrichedData: {} });
    }

    // 3. Call Claude Haiku with web_search tool
    console.log(`🔍 Enriching via Claude: ${venueName} (${placeId})`);

    const message = await anthropic.messages.create({
      model:      'claude-haiku-4-5-20251001',
      max_tokens: 1024,
      tools:      [{ type: 'web_search_20250305', name: 'web_search' }],
      system:     SYSTEM_PROMPT,
      messages:   [{
        role:    'user',
        content: `Find parent-relevant venue information for: ${venueName}`,
      }],
    });

    // 4. Concatenate all text blocks from the response
    let rawText = '';
    for (const block of message.content) {
      if (block.type === 'text') rawText += block.text;
    }

    // 5. Extract the JSON object — strip preamble, markdown fences, trailing text
    const jsonText = extractJson(rawText);
    if (!jsonText) {
      console.error(`❌ No JSON object found in Claude response for ${venueName}:`, rawText.substring(0, 300));
      return res.json({ placeId, venueName, enrichedData: {}, sources: [], confidence: 'web_enriched', cachedAt: null });
    }

    // 6. Parse JSON — gracefully degrade on failure
    let parsed;
    try {
      parsed = JSON.parse(jsonText);
    } catch (parseErr) {
      console.error(`❌ JSON parse failed for ${venueName}:`, jsonText.substring(0, 300));
      return res.json({ placeId, venueName, enrichedData: {}, sources: [], confidence: 'web_enriched', cachedAt: null });
    }

    const { sources = [], ...enrichedData } = parsed;

    // 7. Upsert into MongoDB (90-day TTL)
    const doc = await VenueEnrichment.findOneAndUpdate(
      { placeId },
      {
        placeId,
        venueName,
        enrichedData,
        sources,
        confidence: 'web_enriched',
        expiresAt:  new Date(Date.now() + 90 * 24 * 60 * 60 * 1000),
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    console.log(`✅ Enrichment saved: ${venueName} (${placeId}), sources: ${sources.length}`);

    return res.json({
      placeId:      doc.placeId,
      venueName:    doc.venueName,
      enrichedData: doc.enrichedData,
      sources:      doc.sources,
      confidence:   doc.confidence,
      cachedAt:     null,
    });

  } catch (err) {
    console.error(`❌ Venue enrichment error for ${venueName}:`, err.message);
    return res.json({ placeId, venueName, enrichedData: {}, sources: [], confidence: 'web_enriched', cachedAt: null });
  }
});

module.exports = router;
