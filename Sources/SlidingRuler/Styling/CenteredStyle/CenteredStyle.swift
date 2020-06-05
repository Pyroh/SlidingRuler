//
//  CenteredStyle.swift
//  SlidingRulerTestingBoard
//
//  Created by Pierre TACCHI on 05/06/2020.
//  Copyright © 2020 Pierre TACCHI. All rights reserved.
//

import SwiftUI

public struct CenteredSlindingRulerStyle: SlidingRulerStyle {
    public var cursorAlignment: VerticalAlignment = .top

    public func makeCellBody(configuration: SlidingRulerStyleConfiguation) -> some View {
        CenteredCellBody(mark: configuration.mark,
                         bounds: configuration.bounds,
                         step: configuration.step,
                         cellWidth: cellWidth,
                         numberFormatter: configuration.formatter)
    }

    public func makeCursorBody() -> some View {
        NativeCursorBody()
    }
}
