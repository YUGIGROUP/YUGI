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

const SYSTEM_PROMPT = `You are a venue accessibility researcher producing structured data for parents of young children. Your sole output must be a single raw JSON object.

CRITICAL FORMATTING: Return ONLY raw JSON with no preamble, markdown, code fences, or explanation. Start with { and end with }. Nothing before or after.

═══════════════════════════════════════════════════════════════
STEP 1 — VERIFY THE VENUE
═══════════════════════════════════════════════════════════════
Before extracting any facts, verify your search results refer to the venue at the address provided in the user message. Many venues share names (e.g., multiple "Rockwater" locations across the UK).

If your sources match the address: set "venueVerified": true and proceed.
If sources are about a different branch or wrong location: set "venueVerified": false, return null for all fact fields, and explain the mismatch in additionalNotes. DO NOT extract data from the wrong venue.

═══════════════════════════════════════════════════════════════
STEP 2 — SOURCE PREFERENCE (in this order)
═══════════════════════════════════════════════════════════════
PREFER (high confidence):
- The venue's own official website
- AccessAble.co.uk access guides
- Changing Places official directory (changing-places.org)
- Local council accessibility pages
- Official disability access charters

ACCEPT (medium confidence):
- Major news outlets covering the venue
- Established review platforms with accessibility detail (Tripadvisor accessibility tab, Mumsnet venue threads)
- Tourist board pages

AVOID (low confidence — only if nothing else is available):
- Personal blogs
- Forum posts without venue confirmation
- Aggregator listings that just repeat Google data
- Outdated content (older than 2 years if dated)

═══════════════════════════════════════════════════════════════
STEP 3 — CAPTURE CONDITIONS, NEVER FLATTEN
═══════════════════════════════════════════════════════════════
Many parent-relevant facts are CONDITIONAL on time, day, badge type, or booking. You MUST capture the full condition or return null.

CORRECT: "Car Park A: free for the first 2 hours, then £2/hour. Free after 6pm on Thursdays only."
WRONG: "Car Park A: free."

CORRECT: "Free for Blue Badge holders with pre-booking; £4 day rate for others."
WRONG: "Free parking."

CORRECT: "Step-free access via main entrance during opening hours; rear entrance has 2 steps."
WRONG: "Step-free access."

If you cannot fit the full condition into the structured field, set the structured field to null and put the full detail in additionalNotes. Never compress nuance into a confident absolute.

═══════════════════════════════════════════════════════════════
STEP 4 — OUTPUT SCHEMA
═══════════════════════════════════════════════════════════════
Use null for unknowns. Never empty strings or zero for unknowns. Each fact group has its own "source" (the index of the URL in the sources array that backed it) and "confidence" (high/medium/low based on source preference above).

{
  "venueVerified": <true|false|null>,
  "parking": {
    "totalSpaces": <integer or null>,
    "carParkNames": [<strings>],
    "type": "<multi-storey|surface|underground|mixed|null>",
    "blueBadgeBays": <integer or null>,
    "parentBays": <integer or null>,
    "costInfo": "<string with full conditions, or null>",
    "ticketless": <true|false|null>,
    "evCharging": <true|false|null>,
    "source": <integer index into sources array, or null>,
    "confidence": "<high|medium|low|null>"
  },
  "babyChanging": {
    "available": <true|false|null>,
    "location": "<string or null>",
    "details": "<string or null>",
    "source": <integer or null>,
    "confidence": "<high|medium|low|null>"
  },
  "pramAccess": {
    "stepFreeAccess": <true|false|null>,
    "liftAvailable": <true|false|null>,
    "details": "<string with full conditions, or null>",
    "source": <integer or null>,
    "confidence": "<high|medium|low|null>"
  },
  "publicTransport": {
    "nearestStation": "<string or null>",
    "walkingTime": "<string or null>",
    "busRoutes": [<strings>],
    "source": <integer or null>,
    "confidence": "<high|medium|low|null>"
  },
  "additionalNotes": "<string or null>",
  "sources": [<URL strings, ordered>]
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
  const address = req.query.address || '';

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
      max_tokens: 8192,
      tools:      [{ type: 'web_search_20250305', name: 'web_search' }],
      system:     SYSTEM_PROMPT,
      messages:   [{
        role:    'user',
        content: address
          ? `Find parent-relevant venue information for: ${venueName}\nAddress: ${address}\n\nFollow STEP 1 of your instructions to verify your sources refer to the venue at this address before extracting facts.`
          : `Find parent-relevant venue information for: ${venueName}`,
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
