//
//  RewardView.swift
//  CityChamberHunt
//
//  Created by Irina Saf on 2025-10-01.
//

import SwiftUI

struct RewardView: View {
    let foundCount: Int
    
    var body: some View {
        VStack {
            if foundCount >= 10 {
                Text("🎉 All items found!").font(.headline)
            } else if foundCount > 0 {
                Text("You found \(foundCount) items").font(.headline)
            } else {
                Text("Start your hunt!").font(.headline)
            }
        }
        .padding()
    }
}



#Preview {
    RewardView(foundCount: 5)

}
