//
//  NativeCellBody.swift
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

protocol NativeCellBody: CellBody { }
extension NativeCellBody {
    var maskShape: some Shape {
        let validRange = bounds.clamped(to: cellBounds)
        let boundaryMet = validRange != cellBounds
        let leftOffset: CGFloat
        let rightOffset: CGFloat

        if boundaryMet {
            leftOffset = abs(CGFloat((validRange.lowerBound - cellBounds.lowerBound) / step) * cellWidth)
            rightOffset = abs(CGFloat((cellBounds.upperBound - validRange.upperBound) / step) * cellWidth)
        } else {
            leftOffset = .zero
            rightOffset = .zero
        }
        let maskWidth = cellWidth - (leftOffset + rightOffset)

        return ScaleMask(originX: leftOffset, width: maskWidth)
    }
}

private struct ScaleMask: Shape {
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
