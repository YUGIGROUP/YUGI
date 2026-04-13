//
//  BookingFeedbackButton.swift
//  YUGI
//
//  Add this button to confirmed booking cards where the class time has already passed.
//
//  Usage inside your BookingCard (or BookingsTab row):
//
//      if booking.classEndTime < Date() {
//          BookingFeedbackButton(
//              bookingId: booking.bookingId,
//              className: booking.className
//          )
//      }
//

import SwiftUI

struct BookingFeedbackButton: View {
    let bookingId: String
    let className: String

    @State private var showFeedback = false

    var body: some View {
        Button {
            showFeedback = true
        } label: {
            Label("How was it?", systemImage: "star.bubble")
                .font(.footnote.weight(.semibold))
                .foregroundColor(Color.yugiMocha)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.yugiMocha.opacity(0.10))
                .cornerRadius(20)
        }
        .sheet(isPresented: $showFeedback) {
            PostVisitFeedbackScreen(bookingId: bookingId, className: className)
        }
    }
}
