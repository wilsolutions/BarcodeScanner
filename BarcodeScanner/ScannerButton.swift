//
//  ScannerButton.swift
//  BarcodeScanner
//
//  Created by Wils G. on 2025-03-01.
//

import SwiftUI

struct ScannerButton: View {
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label("Scan Barcode", systemImage: "barcode.viewfinder")
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue.gradient, in: .rect(cornerRadius: 12))
                .foregroundStyle(.white)
                .symbolEffect(.bounce)
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
    }
}

