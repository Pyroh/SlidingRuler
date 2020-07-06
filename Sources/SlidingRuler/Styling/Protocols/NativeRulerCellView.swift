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
import SmoothOperators

protocol NativeRulerCellView: RulerCellView { }
extension NativeRulerCellView {
    var maskShape: some Shape {
        guard !isComplete else { return ScaleMask(originX: .zero, width: cellWidth) }
        guard cellBounds.overlaps(bounds) else { return ScaleMask.zero }

        let availableRange = bounds.clamped(to: cellBounds)

        let leadingOffset: CGFloat = adjustOffset(abs(CGFloat((availableRange.lowerBound - cellBounds.lowerBound) / step) * cellWidth).approximated())
        let trailingOffset: CGFloat = adjustOffset(abs(CGFloat((cellBounds.upperBound - availableRange.upperBound) / step) * cellWidth).approximated())

        let maskWidth = cellWidth - (leadingOffset + trailingOffset)

        return ScaleMask(originX: leadingOffset, width: maskWidth)
    }

    private var hasHalf: Bool { Scale.hasHalf }
    private var fractions: Int { Self.fractions }
    private var fractionWidth: CGFloat { cellWidth / CGFloat(fractions) }

    private func areaLimits(_ area: Int) -> (leading: CGFloat, trailing: CGFloat) {
        let leadingLimit: CGFloat
        let trailingLimit: CGFloat

        let leadingOffset = CGFloat(area) * fractionWidth
        let trailingOffset = CGFloat(area+) * fractionWidth

        if hasHalf {
            let leadingUnitArea = fractions / 2
            let trailingUnitArea = leadingUnitArea-

            if area == 0 { leadingLimit = scale.halfMarkWidth / 2 + scale.halfMarkOffset }
            else if area == leadingUnitArea { leadingLimit = leadingOffset + scale.unitMarkWidth / 2 + scale.unitMarkOffset }
            else { leadingLimit = leadingOffset + scale.fractionMarkWidth / 2 + scale.fractionMarkOffset }

            if area == fractions- { trailingLimit = trailingOffset - scale.unitMarkWidth / 2 + scale.unitMarkOffset }
            else if area == trailingUnitArea { trailingLimit = trailingOffset - scale.unitMarkWidth / 2 + scale.unitMarkOffset }
            else { trailingLimit = trailingOffset - scale.fractionMarkWidth / 2 + scale.fractionMarkOffset }
        } else {
            if area == 0 { leadingLimit = .nan }
            else if Scale.hasHalf && area == (fractions / 2) { leadingLimit = CGFloat(area) * fractionWidth + scale.halfMarkWidth / 2 }
            else { leadingLimit = CGFloat(area) * fractionWidth + fractionWidth / 2 }

            if area == fractions - 1 { trailingLimit = cellWidth -  scale.unitMarkWidth / 2 }
            else if Scale.hasHalf && area == (fractions / 2 - 1) { trailingLimit = CGFloat(area + 1) * fractionWidth + scale.halfMarkWidth / 2 }
            else { trailingLimit = CGFloat(area + 1) * fractionWidth - fractionWidth / 2 }
        }

        return (leadingLimit, trailingLimit)
    }

    private func adjustOffset(_ offset: CGFloat) -> CGFloat {
        guard !offset.isZero else { return offset }

        let area = offset.truncatingRemainder(dividingBy: fractionWidth) > 0 ?
            Int(offset / fractionWidth) :
            Int(offset / fractionWidth)-
        let limits = areaLimits(area)

        if offset < limits.leading { return limits.leading }
        else if offset > limits.trailing { return limits.trailing }
        else { return offset }
    }
}

private struct ScaleMask: Shape {
    let originX: CGFloat
    let centerMaskWidth: CGFloat

    static var zero: Self { .init(originX: .zero, width: .zero) }

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
