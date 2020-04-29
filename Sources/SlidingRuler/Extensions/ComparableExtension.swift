//
//  File.swift
//  
//
//  Created by Pierre TACCHI on 29/04/2020.
//

import Foundation

extension Comparable {
    func clamp(_ x: Self, _ min: Self, _ max: Self) -> Self {
        return Swift.min(Swift.max(x, min), max)
    }
    
    func clamped(to range: ClosedRange<Self>) -> Self {
        clamp(self, range.lowerBound, range.upperBound)
    }
    
    mutating func clamp(to range: ClosedRange<Self>) {
        self = self.clamped(to: range)
    }
    
    func isBound(of range: ClosedRange<Self>) -> Bool {
        range.lowerBound == self || range.upperBound == self
    }
}
