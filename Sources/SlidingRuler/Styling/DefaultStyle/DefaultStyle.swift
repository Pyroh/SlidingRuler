//
//  DefaultSlidingRulerStyle.swift
//
//  SlidingRuler
//
//  MIT License
//
//  Copyright (c) 2020 Pierre Tacchi
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//


import SwiftUI

public struct PrimarySlidingRulerStyle: SlidingRulerStyle {
    public let cursorAlignment: VerticalAlignment = .top

    public func makeCellBody(configuration: SlidingRulerStyleConfiguation) -> some FractionableView {
        DefaultCellBody(mark: configuration.mark,
                        bounds: configuration.bounds,
                        step: configuration.step,
                        cellWidth: cellWidth,
                        numberFormatter: configuration.formatter)
    }
    
    public func makeCursorBody() -> some View {
        NativeCursorBody()
    }
}

struct DefaultStyle_Previews: PreviewProvider {
    struct CellTrio: View {
        let range: ClosedRange<CGFloat>
        let width: CGFloat

        var body: some View {
            HStack(spacing: 0) {
                BlankCellBody(mark: -1, bounds: range, step: 1, cellWidth: width).clipped()
                BlankCellBody(mark: 0, bounds: range, step: 1, cellWidth: width).clipped()
                BlankCellBody(mark: 1, bounds: range, step: 1, cellWidth: width).clipped()
            }
        }
    }

    static var previews: some View {
        CellTrio(range: -0.4...0.9, width: 120)
            .previewLayout(.sizeThatFits)
    }
}
