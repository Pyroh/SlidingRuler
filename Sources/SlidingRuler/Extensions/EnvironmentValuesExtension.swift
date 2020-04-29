//
//  SlideRulerEnvironment.swift
//  Aldo's
//
//  Created by Pierre TACCHI on 14/04/2020.
//  Copyright © 2020 Pierre TACCHI. All rights reserved.
//

import SwiftUI

enum StaticSlideRulerStyleEnvironment {
    @Environment(\.slidingRulerStyle.cellWidth) static var cellWidth
    @Environment(\.slidingRulerStyle.cursorAlignment) static var alignment
    @Environment(\.slidingRulerStyle.isStatic) static var isStatic
}

struct SlidingRulerStyleEnvironmentKey: EnvironmentKey {
    static var defaultValue: AnySlidingRulerStyle { .init(style: DefaultSlidingRulerStyle()) }
}

struct SlideRulerCellOverflow: EnvironmentKey {
    static var defaultValue: Int { 2 }
}

extension EnvironmentValues {
    var slidingRulerStyle: AnySlidingRulerStyle {
        get { self[SlidingRulerStyleEnvironmentKey.self] }
        set { self[SlidingRulerStyleEnvironmentKey.self] = newValue }
    }
    
    var slideRulerCellOverflow: Int {
        get { self[SlideRulerCellOverflow.self] }
        set { self[SlideRulerCellOverflow.self] = newValue }
    }
}
