//
//  Item.swift
//  JokguApplication
//
//  Created by In Cho on 8/20/25.
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
