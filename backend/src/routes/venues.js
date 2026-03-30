const express         = require('express');
const router          = express.Router();
const Anthropic       = require('@anthropic-ai/sdk');
const VenueEnrichment = require('../models/VenueEnrichment');

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

const SYSTEM_PROMPT = `You are a specialist at finding detailed, parent-relevant venue information from the web.
Search the web to find specific details parents need when visiting with babies, toddlers, and young children.

Focus on finding:
1. Parking: total number of spaces, car park names, type (multi-storey/surface/underground), Blue Badge bays count, parent & child bays count, cost/pricing details, whether it is ticketless/ANPR, EV charging availability
2. Baby changing facilities: whether available, exact location within venue (e.g. "first floor near M&S"), any relevant details (e.g. "dedicated parent & baby room")
3. Pram/wheelchair/step-free access: step-free access availability, lifts available, any relevant details
4. Public transport: nearest train/tube/tram station name, approximate walking time from venue, bus route numbers serving the area
5. Any other parent-relevant logistics (feeding rooms, family lifts, accessible toilets, buggy parks, etc.)

Return ONLY a valid JSON object with NO markdown, NO code blocks, NO explanation text — just the raw JSON.
The JSON must match exactly this structure (use null for unknown values, not empty strings):
{
  "parking": {
    "totalSpaces": <integer or null>,
    "carParkNames": [<string array, empty if none known>],
    "type": "<multi-storey|surface|underground|mixed|null>",
    "blueBadgeBays": <integer or null>,
    "parentBays": <integer or null>,
    "costInfo": "<string describing cost or null>",
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
    "walkingTime": "<string e.g. '5 minutes' or null>",
    "busRoutes": [<string array of route numbers, empty if none known>]
  },
  "additionalNotes": "<string with any other parent-relevant info or null>",
  "sources": [<URL strings of pages you found info from, empty if none>]
}`;

// ─── GET /api/venues/:placeId/enrichment ─────────────────────────────────────

router.get('/:placeId/enrichment', async (req, res) => {
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
      return res.status(429).json({
        error:        'Rate limit reached — try again later',
        enrichedData: {},
      });
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
        content: `Find detailed parent-relevant venue information for: ${venueName}`,
      }],
    });

    // 4. Extract text content blocks
    let jsonText = '';
    for (const block of message.content) {
      if (block.type === 'text') jsonText += block.text;
    }
    jsonText = jsonText
      .trim()
      .replace(/^```json\s*/i, '')
      .replace(/^```\s*/i, '')
      .replace(/\s*```$/i, '')
      .trim();

    // 5. Parse JSON — gracefully degrade on failure
    let parsed;
    try {
      parsed = JSON.parse(jsonText);
    } catch (parseErr) {
      console.error(`❌ Failed to parse Claude response for ${venueName}:`, jsonText.substring(0, 300));
      return res.json({ placeId, venueName, enrichedData: {}, sources: [], confidence: 'web_enriched', cachedAt: null });
    }

    const { sources = [], ...enrichedData } = parsed;

    // 6. Upsert into MongoDB (90-day TTL)
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
    // Never break the experience — return empty enrichment on any failure
    return res.json({ placeId, venueName, enrichedData: {}, sources: [], confidence: 'web_enriched', cachedAt: null });
  }
});

module.exports = router;
