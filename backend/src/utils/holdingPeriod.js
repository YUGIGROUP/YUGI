// Holding-period helpers shared by the payments routes, the bookings
// completion route, and (in Phase 2b) the funds-release cron.
//
// Holding window: funds sit in 'held' for HOLDING_WORKING_DAYS working days
// (weekends skipped) after classCompletedAt, then the release cron transfers
// them to the provider's Stripe Connect account.

const HOLDING_WORKING_DAYS = 3;

function calculateWorkingDaysAfter(startDate, workingDays) {
  const currentDate = new Date(startDate);
  let daysAdded = 0;

  while (daysAdded < workingDays) {
    currentDate.setDate(currentDate.getDate() + 1);
    const dayOfWeek = currentDate.getDay();
    if (dayOfWeek !== 0 && dayOfWeek !== 6) {
      daysAdded++;
    }
  }

  return currentDate;
}

// Stamps classCompletedAt + fundsReleaseDate on a booking. Does not save —
// caller is responsible for booking.save() so we don't double-write.
// No-ops if classCompletedAt is already set, so concurrent completion calls
// (e.g. provider taps "complete" after the cron auto-completes in 2b) don't
// reset the release clock.
function applyClassCompletion(booking, completedAt = new Date()) {
  if (booking.classCompletedAt) return false;
  booking.classCompletedAt = completedAt;
  booking.fundsReleaseDate = calculateWorkingDaysAfter(completedAt, HOLDING_WORKING_DAYS);
  return true;
}

module.exports = {
  HOLDING_WORKING_DAYS,
  calculateWorkingDaysAfter,
  applyClassCompletion,
};
