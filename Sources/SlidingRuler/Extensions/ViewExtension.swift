//
//  File.swift
//  
//
//  Created by Pierre TACCHI on 29/04/2020.
//

import SwiftUI

extension View {
    func frame(size: CGSize?, alignment: Alignment = .center) -> some View {
        self.frame(width: size?.width, height: size?.height, alignment: alignment)
    }
    
    func slidingRulerStyle<S>(_ style: S) -> some View where S: SlidingRulerStyle {
        environment(\.slidingRulerStyle, .init(style: style))
    }
    
    func slidingRulerCellOverflow(_ overflow: Int) -> some View {
        environment(\.slideRulerCellOverflow, overflow)
    }
}
