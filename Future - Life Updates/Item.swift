//
//  Item.swift
//  Future - Life Updates
//
//  Created by Quincy Obeng on 9/23/25.
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
