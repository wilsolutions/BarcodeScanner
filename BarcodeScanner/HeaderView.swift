//
//  HeaderView.swift
//  BarcodeScanner
//
//  Created by Wils G. on 2025-03-21.
//

import Foundation


import SwiftUI

struct HeaderView: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: "barcode")
                .font(.system(size: 28))
                .symbolEffect(.pulse)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Barcode Scanner")
                    .font(.title2.bold())
                
                Text("Supports 13+ formats")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            #if os(macOS)
            Circle().frame(width: 8).foregroundStyle(.green)
            #endif
        }
        .padding()
    }
}
