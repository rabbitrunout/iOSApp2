//
//  FlipCard.swift
//  CityChamberHunt
//

import SwiftUI

struct FlipCard<Front: View, Back: View>: View {
    @State private var flipped = false
    let front: () -> Front
    let back: () -> Back
    
    init(@ViewBuilder front: @escaping () -> Front,
         @ViewBuilder back: @escaping () -> Back) {
        self.front = front
        self.back = back
    }
    
    var body: some View {
        ZStack {
            front()
                .opacity(flipped ? 0.0 : 1.0)
                .rotation3DEffect(.degrees(flipped ? 180 : 0),
                                  axis: (x: 0, y: 1, z: 0))

            back()
                .opacity(flipped ? 1.0 : 0.0)
                .rotation3DEffect(.degrees(flipped ? 0 : -180),
                                  axis: (x: 0, y: 1, z: 0))
                // ✅ фикс зеркала: отразить контент обратно
                .scaleEffect(x: -1, y: 1)
        }
        .rotation3DEffect(.degrees(flipped ? 180 : 0),
                          axis: (x: 0, y: 1, z: 0))
        .animation(.spring(response: 0.6,
                           dampingFraction: 0.8,
                           blendDuration: 0.2),
                   value: flipped)
        .onTapGesture { flipped.toggle() }
    }
}

#Preview {
    FlipCard {
        VStack {
            Text("Front Side")
                .font(.title).bold()
            Image(systemName: "star.fill")
                .font(.largeTitle)
                .foregroundColor(.yellow)
            Text("Tap to flip ↻")
                .font(.footnote)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: 240)
        .padding()
        .background(Color.blue.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 6)
    } back: {
        VStack {
            Text("Back Side")
                .font(.title).bold()
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundColor(.purple)
            Text("← Tap again")
                .font(.footnote)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: 240)
        .padding()
        .background(Color.green.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 6)
    }
    .padding()
}
