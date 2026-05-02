const express         = require('express');
const router          = express.Router();
const Anthropic       = require('@anthropic-ai/sdk');
const VenueEnrichment     = require('../models/VenueEnrichment');
const User                = require('../models/User');
const VenueFactFeedback   = require('../models/VenueFactFeedback');
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

IMPORTANT: Each free-text field has a strict character limit shown in its description. Do not exceed it. If you have more detail to share, put it in additionalNotes (capped at 600 chars). Headline facts go in the dedicated fields; long-form context goes in additionalNotes. Be disciplined — the response must fit within 8192 output tokens including any tool use.
PARKING DATA POLICY: If any source mentions parking at the venue — even informally (e.g. "paid parking available", "free parking on-site", "limited parking") — populate parking.costInfo with what was found, attributed to the source. Examples:
- Tagvenue says "on-site paid parking available" → costInfo: "Paid parking on-site (per Tagvenue listing)" with confidence "low"
- Venue's own page mentions "free customer parking" → costInfo: "Free customer parking" with confidence "high"
- Multiple sources mention parking but disagree → use the most authoritative; mention the disagreement in additionalNotes
Only leave parking.costInfo as null if NO source mentions parking at all. Do NOT bury parking information in additionalNotes when the structured costInfo field is the right home for it. additionalNotes is for context that doesn't fit any structured field, not a fallback for laziness.

The same principle applies to babyChanging, pramAccess, and publicTransport — populate the structured fields whenever a source mentions the relevant facts, even informally, with appropriate confidence tier. Use null only when no source mentions it.

Default cap for any other free-text "notes", "info", or "details" field is 150 characters unless this schema specifies otherwise.

{
  "venueVerified": <true|false|null>,
  "parking": {
    "totalSpaces": <integer or null>,
    "carParkNames": [<strings>],
    "type": "<multi-storey|surface|underground|mixed|null>",
    "blueBadgeBays": <integer or null>,
    "parentBays": <integer or null>,
    "costInfo": "<string max 200 chars; headline fact only (e.g. 'Free for Blue Badge after 6pm Thu; otherwise £1.40/hour from Car Park A'), or null>",
    "ticketless": <true|false|null>,
    "evCharging": <true|false|null>,
    "source": <integer index into sources array, or null>,
    "confidence": "<high|medium|low|null>"
  },
  "babyChanging": {
    "available": <true|false|null>,
    "location": "<string or null>",
    "details": "<string max 150 chars, or null>",
    "source": <integer or null>,
    "confidence": "<high|medium|low|null>"
  },
  "pramAccess": {
    "stepFreeAccess": <true|false|null>,
    "liftAvailable": <true|false|null>,
    "details": "<string max 200 chars with key conditions, or null>",
    "source": <integer or null>,
    "confidence": "<high|medium|low|null>"
  },
  "publicTransport": {
    "nearestStation": "<string max 150 chars, or null>",
    "walkingTime": "<string max 150 chars, or null>",
    "busRoutes": [<strings>],
    "source": <integer or null>,
    "confidence": "<high|medium|low|null>"
  },
  "additionalNotes": "<string max 600 chars for longer-form detail, or null>",
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

const FEEDBACK_SOURCES = ['save_prompt', 'mark_visited', 'report_inaccuracy'];
const REPORT_TYPES = ['broken', 'no_longer_true', 'wrong_location', 'never_existed', 'other'];

// ─── POST /api/venues/:placeId/save ───────────────────────────────────────────

router.post('/:placeId/save', protect, async (req, res) => {
  const { venueName: rawName } = req.body;
  if (typeof rawName !== 'string' || rawName.trim().length === 0 || rawName.trim().length > 200) {
    return res.status(400).json({ success: false, message: 'venueName required' });
  }

  try {
    const user = await User.findById(req.user._id || req.user.id);

    const existing = user.savedVenues.find((v) => v.placeId === req.params.placeId);
    if (existing) {
      return res.status(200).json({ success: true, savedVenue: existing, alreadySaved: true });
    }

    user.savedVenues.push({
      placeId:   req.params.placeId,
      venueName: rawName.trim(),
      savedAt:   new Date(),
    });
    await user.save();
    const savedVenue = user.savedVenues[user.savedVenues.length - 1];
    return res.status(200).json({ success: true, savedVenue, alreadySaved: false });
  } catch (err) {
    console.error('POST /:placeId/save error:', err);
    return res.status(500).json({ success: false, message: 'Failed to save venue' });
  }
});

// ─── DELETE /api/venues/:placeId/save ─────────────────────────────────────────

router.delete('/:placeId/save', protect, async (req, res) => {
  try {
    const user = await User.findById(req.user._id || req.user.id);

    const beforeCount = user.savedVenues.length;
    user.savedVenues = user.savedVenues.filter((v) => v.placeId !== req.params.placeId);
    await user.save();
    return res.status(200).json({ success: true, removed: beforeCount > user.savedVenues.length });
  } catch (err) {
    console.error('DELETE /:placeId/save error:', err);
    return res.status(500).json({ success: false, message: 'Failed to remove saved venue' });
  }
});

// ─── POST /api/venues/:placeId/feedback ───────────────────────────────────────

router.post('/:placeId/feedback', protect, async (req, res) => {
  const { venueName: rawVenueName, source, facts, overallComment } = req.body;
  const parentId = req.user._id || req.user.id;

  if (typeof rawVenueName !== 'string' || rawVenueName.trim().length === 0 || rawVenueName.trim().length > 200) {
    return res.status(400).json({ success: false, message: 'venueName must be a non-empty string at most 200 characters' });
  }
  if (!FEEDBACK_SOURCES.includes(source)) {
    return res.status(400).json({ success: false, message: 'source must be save_prompt, mark_visited, or report_inaccuracy' });
  }
  if (!Array.isArray(facts) || facts.length < 1) {
    return res.status(400).json({ success: false, message: 'facts must be a non-empty array' });
  }

  for (let i = 0; i < facts.length; i++) {
    const f = facts[i];
    if (!f || typeof f !== 'object') {
      return res.status(400).json({ success: false, message: `facts[${i}] must be an object` });
    }
    if (typeof f.factPath !== 'string' || f.factPath.trim().length === 0) {
      return res.status(400).json({ success: false, message: `facts[${i}].factPath must be a non-empty string` });
    }
    if (typeof f.agreed !== 'boolean') {
      return res.status(400).json({ success: false, message: `facts[${i}].agreed must be a boolean` });
    }
    if (f.comment !== undefined && f.comment !== null) {
      if (typeof f.comment !== 'string' || f.comment.length > 500) {
        return res.status(400).json({ success: false, message: `facts[${i}].comment must be a string at most 500 characters` });
      }
    }
    if (f.reportType !== undefined && f.reportType !== null) {
      if (!REPORT_TYPES.includes(f.reportType)) {
        return res.status(400).json({ success: false, message: `facts[${i}].reportType must be one of: ${REPORT_TYPES.join(', ')}` });
      }
    }
  }

  if (overallComment !== undefined && overallComment !== null) {
    if (typeof overallComment !== 'string' || overallComment.length > 500) {
      return res.status(400).json({ success: false, message: 'overallComment must be a string at most 500 characters' });
    }
  }

  const venueName = rawVenueName.trim();
  const placeId = req.params.placeId;

  try {
    const events = facts.map((fact) => {
      const evt = {
        placeId,
        venueName,
        factPath: fact.factPath.trim(),
        parentId,
        agreed: fact.agreed,
        source,
      };
      if (fact.comment !== undefined && fact.comment !== null && fact.comment !== '') {
        evt.comment = fact.comment;
      }
      if (fact.reportType !== undefined && fact.reportType !== null) {
        evt.reportType = fact.reportType;
      }
      return evt;
    });

    if (
      overallComment !== undefined &&
      overallComment !== null &&
      overallComment.trim() !== ''
    ) {
      events.push({
        placeId,
        venueName,
        factPath: 'overall',
        parentId,
        agreed: true,
        comment: overallComment.trim(),
        source,
      });
    }

    const created = await VenueFactFeedback.insertMany(events);

    try {
      const user = await User.findById(parentId);
      if (user) {
        const sv = user.savedVenues.find((v) => v.placeId === placeId);
        if (sv) {
          sv.feedbackSubmitted = true;
          await user.save();
        }
      }
    } catch (e) {
      console.warn('Failed to mark savedVenue feedbackSubmitted:', e.message);
    }

    return res.status(201).json({ success: true, eventsCreated: created.length });
  } catch (err) {
    console.error('POST /:placeId/feedback error:', err);
    return res.status(500).json({ success: false, message: 'Failed to submit feedback' });
  }
});

module.exports = router;
