//
//  DefaultCellBody.swift
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

struct DefaultCellBody: View {
    private struct InsideMask: Shape {
        let originX: CGFloat
        let centerMaskWidth: CGFloat
        
        init(originX: CGFloat, width: CGFloat) {
            self.originX = originX
            self.centerMaskWidth = width
        }
        
        func path(in rect: CGRect) -> Path {
            var p = Path()
            let centerRect = CGRect(origin: .init(x: originX, y: 0),
                                    size: .init(width: centerMaskWidth, height: rect.height))
            p.addRect(centerRect)
            
            return p
        }
    }
    
    private struct OutsideMask: Shape {
        let leftWidth: CGFloat
        let rightOrigin: CGFloat
        let rightWidth: CGFloat
        
        func path(in rect: CGRect) -> Path {
            let height = rect.height
            let leftRect = CGRect(origin: .zero, size: .init(width: leftWidth, height: height))
            let rightRect = CGRect(origin: .init(x: rightOrigin, y: 0), size: .init(width: rightWidth, height: height))
            var p = Path()
            
            p.addRect(leftRect)
            p.addRect(rightRect)
            
            return p
        }
    }
    
    let mark: Double
    let bounds: ClosedRange<Double>
    let step: Double
    let numberFormatter: NumberFormatter?
    let cellWidth: CGFloat
    
    private var displayMark: String { numberFormatter?.string(for: mark) ?? "\(mark)" }
    
    var body: some View {
        let overflow = step / 2
        let initialRange = ClosedRange(uncheckedBounds: (mark - overflow, mark + overflow))
        let validRange = bounds.clamped(to: initialRange)
        let boundaryMet = validRange != initialRange
        let leftMaskWidth: CGFloat
        let rightMarkWidth: CGFloat
        
        if boundaryMet {
            leftMaskWidth = abs(CGFloat((validRange.lowerBound - initialRange.lowerBound) / step) * cellWidth)
            rightMarkWidth = abs(CGFloat((initialRange.upperBound - validRange.upperBound) / step) * cellWidth)
        } else {
            leftMaskWidth = .zero
            rightMarkWidth = .zero
        }
        let centerMaskWidth = cellWidth - (leftMaskWidth + rightMarkWidth)
        
        let markColor: Color = centerMaskWidth > 0 ? .init(.label) : .init(.tertiaryLabel)
        let scale = ScaleView(width: cellWidth)
        
        return VStack {
            ZStack {
                scale.equatable().foregroundColor(.init(.label))
                    .clipShape(InsideMask(originX: leftMaskWidth, width: centerMaskWidth))
                scale.equatable().foregroundColor(.init(.tertiaryLabel))
            }
            Spacer()
            Text(verbatim: displayMark).font(Font.footnote.monospacedDigit()).foregroundColor(markColor)
        }
        .frame(width: cellWidth).fixedSize()
        .lineLimit(1)
    }
}
