//
//  SlidingRuler.swift
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

@available(iOS 13.0, *)
public struct SlidingRuler<V>: View where V: BinaryFloatingPoint, V.Stride: BinaryFloatingPoint {
    typealias S = V.Stride

    @Environment(\.slidingRulerCellOverflow) private var cellOverflow

    @Environment(\.slidingRulerStyle) private var style
    @Environment(\.slidingRulerStyle.cellWidth) private var cellWidth
    @Environment(\.slidingRulerStyle.cursorAlignment) private var verticalCursorAlignment
    @Environment(\.slidingRulerStyle.fractions) private var fractions
    @Environment(\.slidingRulerStyle.hasHalf) private var hasHalf

    @Environment(\.layoutDirection) private var layoutDirection

    /// Bound value.
    @Binding private var value: V
    /// Possible value range.
    private let bounds: ClosedRange<V>
    /// Value stride.
    private let step: S
    /// When to snap.
    private let snap: Mark
    /// When to tick.
    private let tick: Mark
    /// Edit changed callback.
    private let editingChangedCallback: (Bool) -> ()
    /// Number formatter for ruler's marks.
    private let formatter: NumberFormatter?

    /// Width of the control, retrieved through preference key.
    @State private var controlWidth: CGFloat?
    /// Height of the ruller, retrieved through preference key.
    @State private var rulerHeight: CGFloat?

    /// Cells of the ruler.
    @State private var cells: [RulerCell<V>] = []

    /// Control state.
    @State private var state: SlidingRulerState = .idle
    /// The reference offset set at the start of a drag session.
    @State private var referenceOffset: CGSize = .zero
    /// The virtual ruler's drag offset.
    @State private var dragOffset: CGSize = .zero
    /// Offset of the ruler's displayed marks.
    @State private var markOffset: Double = .zero

    /// Non-bound value used for rubber release animation.
    @State private var animatedValue: V = .zero
    /// The last value the receiver did set. Used to define if the rendered value was set by the receiver or from another component.
    @State private var lastValueSet: V = .zero

    /// VSynch timer that drives inertial animation.
    @State private var inertialTimer: VSynchedTimer? = nil

    /// Allowed drag offset range.
    private var dragBounds: ClosedRange<CGFloat> {
        let step = CGFloat(self.step)
        let lower = bounds.upperBound.isInfinite ? -CGFloat.infinity : -CGFloat(bounds.upperBound) * cellWidth / step
        let upper = bounds.lowerBound.isInfinite ? CGFloat.infinity : -CGFloat(bounds.lowerBound) * cellWidth / step
        return .init(uncheckedBounds: (lower, upper))
    }

    /// Over-ranged drag rubber should be released.
    private var isRubberBandNeedingRelease: Bool { !dragBounds.contains(dragOffset.width) }
    /// Amount of units the ruler can translate in both direction before needing to refresh the cells and reset offset.
    private var cellWidthOverflow: CGFloat { cellWidth * CGFloat(cellOverflow) }
    /// Current value clamped to the receiver's value bounds.
    private var clampedValue: V { value.clamped(to: bounds) }

    /// Ruler offset used to render the control depending on the state.
    private var effectiveOffset: CGSize {
        switch state {
        case .idle:
            return self.offset(fromValue: clampedValue ?? 0)
        case .animating:
            return self.offset(fromValue: animatedValue ?? 0)
        default:
            return dragOffset
        }
    }
    /// Receiver's value used to compute things depending on the state.
    private var effectiveValue: V {
        switch state {
        case .idle, .flicking:
            return clampedValue ?? 0
        case .animating:
            return animatedValue ?? 0
        default:
            return value ?? 0
        }
    }

    /// Creates a SlidingRuler
    /// - Parameters:
    ///   - value: A binding connected to the control value.
    ///   - bounds: A closed range of possible values. Defaults to `-V.infinity...V.infinity`.
    ///   - step: The stride of the SlidingRuler. Defaults to `1`.
    ///   - snap: The ruler's marks stickyness. Defaults to `.none`
    ///   - tick: The graduation type that produce an haptic feedback when reached. Defaults to `.none`
    ///   - onEditingChanged: A closure executed when a drag session happens. It receives a boolean value set to `true` when the drag session starts and `false` when the value stops changing. Defaults to no action.
    ///   - formatter: A `NumberFormatter` instance the ruler uses to format the ruler's marks. Defaults to `nil`.
    public init(value: Binding<V>,
         in bounds: ClosedRange<V> = -V.infinity...V.infinity,
         step: V.Stride = 1,
         snap: Mark = .none,
         tick: Mark = .none,
         onEditingChanged: @escaping (Bool) -> () = { _ in },
         formatter: NumberFormatter? = nil) {
        self._value = value
        self.bounds = bounds
        self.step = step
        self.snap = snap
        self.tick = tick
        self.editingChangedCallback = onEditingChanged
        self.formatter = formatter
    }
    
    public var body: some View {
        let renderedValue: V
        let renderedOffset: CGSize

        switch self.state {
        case .flicking:
            if self.value != self.lastValueSet {
                self.inertialTimer?.cancel()
                NextLoop { self.state = .idle }
                renderedValue = clampedValue ?? 0
                renderedOffset = self.offset(fromValue: renderedValue)
            } else {
                fallthrough
            }
        case .dragging:
            renderedOffset = dragOffset
            renderedValue = self.value(fromOffset: renderedOffset)
        case .animating:
            if value == animatedValue {
                NextLoop { self.state = .idle }
            }
            print(value, animatedValue, $animatedValue.transaction)
            renderedValue = animatedValue
            renderedOffset = self.offset(fromValue: renderedValue)
        case .idle:
            renderedValue = clampedValue ?? 0
            renderedOffset = self.offset(fromValue: renderedValue)
        }

        return GeometryReader { proxy in
            ZStack(alignment: .init(horizontal: .center, vertical: self.verticalCursorAlignment)) {
                Ruler(cells: self.cells, step: Double(self.step), markOffset: self.markOffset, bounds: self.bounds, formatter: self.formatter)
                    .equatable()
                    .animation(nil)
                    .modifier(InfiniteOffsetEffect(offset: renderedOffset, maxOffset: self.cellWidthOverflow))
                self.style.makeCursorBody()
            }
            .frame(width: proxy.size.width)
            .clipped()
            .propagateWidth(ControlWidthPreferenceKey.self)
            .fixedSize(horizontal: false, vertical: true)
        }
        .onHorizontalDragGesture(initialTouch: firstTouchHappened, perform: horizontalDragAction(withValue:))
        .modifier(InfiniteMarkOffsetModifier(renderedValue, step: step))
        .onPreferenceChange(MarkOffsetPreferenceKey.self) { self.markOffset = $0 }
        .onPreferenceChange(ControlWidthPreferenceKey.self) {
            self.controlWidth = $0
            self.updateCellsIfNeeded()
        }
        .onHeightPreferenceChange(RulerHeightPreferenceKey.self, storeValueIn: $rulerHeight)
        .transaction {
            if $0.animation != nil && self.state == .idle { $0.animation = .easeIn(duration: 0.1) }
        }
        .frame(height: rulerHeight)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: Drag Gesture Management
extension SlidingRuler {

    /// Composite callback passed to the horizontal drag gesture recognizer.
    private func horizontalDragAction(withValue value: HorizontalDragGestureValue) {
        switch value.state {
        case .began: horizontalDragBegan(value)
        case .changed: horizontalDragChanged(value)
        case .ended: horizontalDragEnded(value)
        default: return
        }
    }

    /// Callback handling first touch event.
    private func firstTouchHappened() {
        if state == .flicking {
            inertialTimer?.cancel()
            state = .idle
        }
    }

    /// Callback handling horizontal drag gesture begining.
    private func horizontalDragBegan(_ value: HorizontalDragGestureValue) {
        editingChangedCallback(true)
        dragOffset = self.offset(fromValue: clampedValue ?? 0)
        referenceOffset = dragOffset
        state = .dragging
    }

    /// Callback handling horizontal drag gesture updating.
    private func horizontalDragChanged(_ value: HorizontalDragGestureValue) {
        let newOffset = self.directionalOffset(value.translation.horizontal + referenceOffset)
        let newValue = self.value(fromOffset: newOffset)
        
        self.tickIfNeeded(dragOffset.width, newOffset.width)
        
        withoutAnimation {
            self.setValue(newValue)
            dragOffset = self.applyRubber(to: newOffset)
        }
    }

    /// Callback handling horizontal drag gesture ending.
    private func horizontalDragEnded(_ value: HorizontalDragGestureValue) {
        if isRubberBandNeedingRelease {
            self.releaseRubberBand()
            self.endDragSession()
        } else if abs(value.velocity) > 40 {
            self.applyInertia(startLoc: value.startLocation, releaseLoc: value.location, initialVelocity: value.velocity)
        } else {
            state = .idle
            self.endDragSession()
            self.snapIfNeeded()
        }
    }

    /// Drag session clean-up.
    private func endDragSession() {
        referenceOffset = .zero
        self.editingChangedCallback(false)
    }
}

// MARK: Value Management
extension SlidingRuler {

    /// Compute the value from the given ruler's offset.
    private func value(fromOffset offset: CGSize) -> V {
        self.directionalValue(-V(offset.width / cellWidth) * V(step))
    }

    /// Compute the ruler's offset from the given value.
    private func offset(fromValue value: V) -> CGSize {
        let width = CGFloat(-value * V(cellWidth) / V(step))
        return self.directionalOffset(.init(horizontal: width))
    }

    /// Sets the value.
    private func setValue(_ newValue: V) {
        let clampedValue = newValue.clamped(to: bounds)
        
        if clampedValue.isBound(of: bounds) && !value.isBound(of: self.bounds) {
            self.boundaryMet()
        }
        
        if lastValueSet != clampedValue { lastValueSet = clampedValue }
        if value != clampedValue { value = clampedValue }
    }

    /// Snaps the value to the nearest mark based on the `snap` property.
    private func snapIfNeeded() {
        let nearest = self.nearestSnapValue(self.value)
        guard nearest != value else { return }

        let delta = abs(nearest - value)
        let fractionalValue = V(step / S(fractions))

        guard delta < fractionalValue else { return }

        let animThreshold = V(step / 200)
        let animation: Animation? = delta > animThreshold ? .easeOut(duration: 0.1) : nil

        dragOffset = offset(fromValue: nearest)
        withAnimation(animation) { self.value = nearest }
    }

    /// Returns the nearest value to snap on based on the `snap` property.
    private func nearestSnapValue(_ value: V) -> V {
        let t: V

        switch snap {
        case .unit: t = V(step)
        case .half: t = V(step / 2)
        case .fraction: t = V(step / S(fractions))
        default: return value
        }

        let lower = (value / t).rounded(.down) * t
        let upper = (value / t).rounded(.up) * t
        let deltaDown = abs(value - lower)
        let deltaUp = abs(value - upper)
        return deltaDown < deltaUp ? lower : upper
    }

    ///  Transforms any numerical value based the layout direction. /!\ not properly tested.
    func directionalValue<T: Numeric>(_ value: T) -> T {
        value * (layoutDirection == .rightToLeft ? -1 : 1)
    }

    /// Transforms an offsetr based on the layout direction. /!\ not properly tested.
    func directionalOffset(_ offset: CGSize) -> CGSize {
        let width = self.directionalValue(offset.width)
        return .init(width: width, height: offset.height)
    }
}

// MARK: Control Update
extension SlidingRuler {

    /// Adjusts the number of cells as the control size changes.
    private func updateCellsIfNeeded() {
        guard let controlWidth = controlWidth else { return }
        let count = (Int(ceil(controlWidth / cellWidth)) + cellOverflow * 2).nextOdd()
        if count != cells.count { self.populateCells(count: count) }
    }

    /// Creates `count` cells for the ruler.
    private func populateCells(count: Int) {
        let boundary = count.previousEven() / 2
        cells = (-boundary...boundary).enumerated().map { RulerCell(V($0.element)) }
    }
}

// MARK: Physic Simulation
extension SlidingRuler {

    /// Apply inertia to the ruler once dragged and released with a sufficient velocity.
    /// - Parameters:
    ///   - startLoc: The drag event start location in the view.
    ///   - releaseLoc: The drag event release location in the view.
    ///   - initialVelocity: Drag velocity when the drag event ended.
    private func applyInertia(startLoc: CGPoint, releaseLoc: CGPoint, initialVelocity: CGFloat) {
        let friction = 2345.6
        let bounceFriction = 45678.9
        var location = releaseLoc.x
        var speed = abs(initialVelocity)
        let direction = speed / initialVelocity
        state = .flicking
        
        inertialTimer = .init(animations: { (timeFrame) in
            location += direction * speed * CGFloat(timeFrame)
            let translation = CGSize(horizontal: location - startLoc.x)
            let newOffset = self.directionalOffset(translation + self.referenceOffset)
            let newValue = self.value(fromOffset: newOffset)
            
            self.tickIfNeeded(self.dragOffset.width, newOffset.width)
            
            withoutAnimation {
                self.setValue(newValue)
                self.dragOffset = self.applyRubber(to: newOffset)
            }
            
            if !self.isRubberBandNeedingRelease {
                speed = speed - CGFloat(friction * timeFrame)
            } else {
                speed = speed - CGFloat(bounceFriction * timeFrame)
            }
            
            if speed <= 0 { self.inertialTimer?.stop() }
        }, completion: { (completed) in
            if self.isRubberBandNeedingRelease {
                self.releaseRubberBand()
            } else if completed {
                self.state = .idle
                self.snapIfNeeded()
            }
            
            self.endDragSession()
        })
    }

    /// Applies rubber effect to an off-range offset.
    private func applyRubber(to offset: CGSize) -> CGSize {
        let dragBounds = self.dragBounds
        guard !dragBounds.contains(offset.width) else { return offset }
        
        let tx = offset.width
        let nearest = tx.clamped(to: dragBounds)
        let delta = tx - nearest
        let factor: CGFloat = delta < 0 ? -1 : 1
        let c = cellWidth * 2.5
        let rubberDelta = c * (1 + log10((abs(delta) + c)/c)) - c
        let rubberTx = nearest + factor * rubberDelta
        
        return .init(horizontal: rubberTx)
    }

    /// Animates an off-range offset back in place
    private func releaseRubberBand() {
        self.animatedValue = self.value(fromOffset: effectiveOffset)
        self.state = .animating
        self.dragOffset = self.offset(fromValue: self.value)
        NextLoop {
            withAnimation(.spring(response: 0.667, dampingFraction: 1.0)) {
                self.animatedValue = self.value
            }
        }
    }
}

// MARK: Tick Management
extension SlidingRuler {
    private func boundaryMet() {
        let fg = UIImpactFeedbackGenerator(style: .rigid)
        fg.impactOccurred(intensity: 0.667)
    }

    private func tickIfNeeded(_ offset0: CGFloat, _ offset1: CGFloat) {
        let dragBounds = self.dragBounds
        guard dragBounds.contains(offset0), dragBounds.contains(offset1),
            !offset0.isBound(of: dragBounds), !offset1.isBound(of: dragBounds) else { return }
        
        let t: CGFloat
        switch tick {
        case .unit: t = cellWidth
        case .half: t = hasHalf ? cellWidth / 2 : cellWidth
        case .fraction: t = cellWidth / CGFloat(fractions)
        case .none: return
        }
        
        if offset1 == 0 ||
            (offset0 < 0) != (offset1 < 0) ||
            Int(offset0 / t) != Int(offset1 / t) {
            valueTick()
        }
    }
    
    private func valueTick() {
        let fg = UIImpactFeedbackGenerator(style: .light)
        fg.impactOccurred(intensity: 0.5)
    }
}
