//
//  Item.swift
//  OpenCore
//
//  Created by Bambang Tri Rahmat Doni on 16/06/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
