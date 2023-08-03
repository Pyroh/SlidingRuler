//
//  Ruler.swift
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

struct Ruler: View, Equatable {
    @Environment(\.slidingRulerStyle) private var style

    let cells: [RulerCell]
    let step: CGFloat
    let markOffset: CGFloat
    let bounds: ClosedRange<CGFloat>
    let formatter: NumberFormatter?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(self.cells) { cell in
                self.style.makeCellBody(configuration: self.configuration(forCell: cell))
            }
        }
        .animation(nil)
    }

    private func configuration(forCell cell: RulerCell) -> SlidingRulerStyleConfiguation {
        return .init(mark: (cell.mark + markOffset) * step, bounds: bounds, step: step, formatter: formatter)
    }

    static func ==(lhs: Self, rhs: Self) -> Bool {
        (lhs.step == rhs.step) && (lhs.cells.count == rhs.cells.count) && (lhs.markOffset == rhs.markOffset)
    }
}

struct Ruler_Previews: PreviewProvider {
    static var previews: some View {
        Ruler(cells: [.init(CGFloat(0))],
              step: 1.0, markOffset: 0, bounds: -1...1, formatter: nil)
    }
}
