/**
 * Refreshes seed classes' one-off classDates to sensible UPCOMING dates so search,
 * day-filtering and booking flows all demo properly.
 *
 * Why this exists: seed classes are one-offs (a single classDate, no recurringDays).
 * Their dates were entered by hand and go stale — once every classDate is in the
 * past, the recommend endpoint (correctly) drops them and the demo looks empty.
 * updateClassDates.js used to "fix" this with HARDCODED dates, which just goes stale
 * again. This script computes dates RELATIVE to today, so re-running rolls them
 * forward — it never goes stale.
 *
 * What it does: each one-off class is assigned a weekday (spread across the set for a
 * weekday/weekend mix) and given 3 weekly sessions on that day, staggered so the set
 * spans the next ~6–8 weeks. The one-off shape is preserved: only classDates is
 * written; recurringDays and timeSlots are left untouched. Classes that already have
 * recurringDays are treated as genuinely recurring and skipped.
 *
 * Idempotent: re-running recomputes relative to "now" and overwrites classDates.
 *
 * DRY RUN BY DEFAULT — prints old vs proposed dates and writes nothing.
 * Pass --apply to actually write.
 *
 * Run from backend/ (uses the same env/connection pattern as the other scripts):
 *   railway run node scripts/refresh-seed-dates.js            # dry run
 *   railway run node scripts/refresh-seed-dates.js --apply    # write
 */

const mongoose = require('mongoose');
require('dotenv').config();

const Class = require('../src/models/Class');

const APPLY = process.argv.includes('--apply');

// Weekday numbers as Date.getDay() returns them (0=Sun … 6=Sat).
const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
// Rotation deliberately mixes weekends (Sat/Sun) in with weekdays so the refreshed
// set exercises both. Classes are assigned round-robin from this list.
const WEEKDAY_ROTATION = [6, 1, 0, 3, 5, 2, 4]; // Sat, Mon, Sun, Wed, Fri, Tue, Thu
const SESSIONS_PER_CLASS = 3;
const SESSION_HOUR = 10; // 10:00 local — arbitrary but sensible late-morning slot.

// The next calendar date on `targetDay`, strictly in the future, plus `weeksAhead`
// whole weeks. Relative to now, so results roll forward on every run.
function nextWeekday(targetDay, weeksAhead = 0) {
  const d = new Date();
  d.setHours(SESSION_HOUR, 0, 0, 0);
  do {
    d.setDate(d.getDate() + 1);
  } while (d.getDay() !== targetDay);
  d.setDate(d.getDate() + weeksAhead * 7);
  return d;
}

function fmt(d) {
  const date = d instanceof Date ? d : new Date(d);
  if (isNaN(date.getTime())) return '(invalid)';
  return `${date.toISOString().slice(0, 10)} (${DAY_NAMES[date.getDay()]})`;
}

async function main() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/yugi');
  console.log(`✅ Connected to MongoDB\n${APPLY ? '✍️  APPLY MODE — writing changes' : '🔍 DRY RUN — no changes written. Re-run with --apply to write.'}\n`);

  // Deterministic ordering so weekday assignment (and therefore the spread) is stable
  // across runs regardless of Mongo's return order.
  const classes = await Class.find({}).sort({ _id: 1 });

  let toUpdate = 0;
  let skippedRecurring = 0;
  const ops = [];

  let i = 0;
  for (const cls of classes) {
    const oldDates = (cls.classDates || []).map(fmt).join(', ') || '(none)';

    if ((cls.recurringDays || []).length > 0) {
      skippedRecurring++;
      console.log(`• ${cls.name}\n    SKIPPED — has recurringDays: ${cls.recurringDays.join(', ')}`);
      continue;
    }

    const weekday = WEEKDAY_ROTATION[i % WEEKDAY_ROTATION.length];
    const startWeek = i % 5; // stagger first sessions across 5 different starting weeks
    const newDates = [];
    for (let s = 0; s < SESSIONS_PER_CLASS; s++) {
      newDates.push(nextWeekday(weekday, startWeek + s));
    }

    console.log(`• ${cls.name}  [${DAY_NAMES[weekday]}]`);
    console.log(`    old classDates: ${oldDates}`);
    console.log(`    new classDates: ${newDates.map(fmt).join(', ')}`);

    toUpdate++;
    ops.push({ id: cls._id, classDates: newDates });
    i++;
  }

  console.log(`\nSummary: ${toUpdate} one-off class(es) to update, ${skippedRecurring} recurring skipped.`);

  if (APPLY && ops.length > 0) {
    for (const op of ops) {
      await Class.updateOne({ _id: op.id }, { $set: { classDates: op.classDates } });
    }
    console.log(`✍️  Applied: updated classDates on ${ops.length} class(es).`);
  } else if (!APPLY) {
    console.log('Nothing written. Re-run with --apply to persist these dates.');
  }

  await mongoose.disconnect();
  process.exit(0);
}

main().catch((err) => {
  console.error('❌ Error:', err);
  process.exit(1);
});
