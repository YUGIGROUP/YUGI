// Unit tests for Booking#fundsLeftPlatform().
// Pure in-memory: documents are built with `new Booking(...)` and never saved,
// so importing the model must NOT open a Mongo connection.

const Booking = require('../Booking');

describe('Booking#fundsLeftPlatform', () => {
  test("paymentStatus 'released' -> true", () => {
    const booking = new Booking({ paymentStatus: 'released' });
    expect(booking.fundsLeftPlatform()).toBe(true);
  });

  test('fundsReleased true (nothing else set) -> true', () => {
    const booking = new Booking({ paymentStatus: 'held', fundsReleased: true });
    expect(booking.fundsLeftPlatform()).toBe(true);
  });

  test('stripeTransferId set (nothing else set) -> true', () => {
    const booking = new Booking({ paymentStatus: 'held', stripeTransferId: 'tr_123' });
    expect(booking.fundsLeftPlatform()).toBe(true);
  });

  test('releaseInProgress true (nothing else set) -> true', () => {
    const booking = new Booking({ paymentStatus: 'held', releaseInProgress: true });
    expect(booking.fundsLeftPlatform()).toBe(true);
  });

  test("plain held booking ('held', none of the above) -> false", () => {
    const booking = new Booking({ paymentStatus: 'held' });
    expect(booking.fundsLeftPlatform()).toBe(false);
  });

  test("legacy 'paid' booking (none of the above) -> false", () => {
    const booking = new Booking({ paymentStatus: 'paid' });
    expect(booking.fundsLeftPlatform()).toBe(false);
  });

  test('several release signals set at once -> true', () => {
    const booking = new Booking({
      paymentStatus: 'released',
      fundsReleased: true,
      stripeTransferId: 'tr_456',
      releaseInProgress: true,
    });
    expect(booking.fundsLeftPlatform()).toBe(true);
  });
});
