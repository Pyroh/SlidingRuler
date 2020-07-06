//
//  CellBody.swift
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

public protocol RulerCellView: FractionableView, Equatable {
    associatedtype Scale: ScaleView
    associatedtype MaskShape: Shape

    var mark: CGFloat { get }
    var bounds: ClosedRange<CGFloat> { get }
    var cellBounds: ClosedRange<CGFloat> { get }
    var step: CGFloat { get }
    var cellWidth: CGFloat { get }

    var scale: Scale { get }
    var maskShape: MaskShape { get }
}

extension RulerCellView {
    static var fractions: Int { Scale.fractions }

    var cellBounds: ClosedRange<CGFloat> {
        ClosedRange(uncheckedBounds: (mark - step / 2, mark + step / 2))
    }

    var isComplete: Bool { bounds.contains(cellBounds) }

    var body: some View {
        ZStack {
            scale
                .equatable()
                .foregroundColor(.init(.label))
                .clipShape(maskShape)
            scale
                .equatable()
                .foregroundColor(.init(.tertiaryLabel))
        }
        .frame(width: cellWidth)
    }

    static func ==(_ lhs: Self, _ rhs: Self) -> Bool {
        lhs.isComplete && rhs.isComplete
    }
}
