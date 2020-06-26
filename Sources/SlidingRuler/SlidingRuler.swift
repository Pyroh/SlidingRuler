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

    @Environment(\.slidingRulerCellOverflow) private var cellOverflow

    @Environment(\.slidingRulerStyle) private var style
    @Environment(\.slidingRulerStyle.cellWidth) private var cellWidth
    @Environment(\.slidingRulerStyle.cursorAlignment) private var verticalCursorAlignment
    @Environment(\.slidingRulerStyle.fractions) private var fractions
    @Environment(\.slidingRulerStyle.hasHalf) private var hasHalf

    @Environment(\.layoutDirection) private var layoutDirection

    /// Bound value.
    @Binding private var controlValue: V
    /// Possible value range.
    private let bounds: ClosedRange<CGFloat>
    /// Value stride.
    private let step: CGFloat
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
    @State private var cells: [RulerCell] = [.init(CGFloat(0))]

    /// Control state.
    @State private var state: SlidingRulerState = .idle
    /// The reference offset set at the start of a drag session.
    @State private var referenceOffset: CGSize = .zero
    /// The virtual ruler's drag offset.
    @State private var dragOffset: CGSize = .zero
    /// Offset of the ruler's displayed marks.
    @State private var markOffset: CGFloat = .zero

    /// Non-bound value used for rubber release animation.
    @State private var animatedValue: CGFloat = .zero
    /// The last value the receiver did set. Used to define if the rendered value was set by the receiver or from another component.
    @State private var lastValueSet: CGFloat = .zero

    /// VSynch timer that drives animations.
    @State private var animationTimer: VSynchedTimer? = nil

    private var value: CGFloat {
        get { CGFloat(controlValue) ?? 0 }
        nonmutating set { controlValue = V(newValue) }
    }

    /// Allowed drag offset range.
    private var dragBounds: ClosedRange<CGFloat> {
        let lower = bounds.upperBound.isInfinite ? -CGFloat.infinity : -bounds.upperBound * cellWidth / step
        let upper = bounds.lowerBound.isInfinite ? CGFloat.infinity : -bounds.lowerBound * cellWidth / step
        return .init(uncheckedBounds: (lower, upper))
    }

    /// Over-ranged drag rubber should be released.
    private var isRubberBandNeedingRelease: Bool { !dragBounds.contains(dragOffset.width) }
    /// Amount of units the ruler can translate in both direction before needing to refresh the cells and reset offset.
    private var cellWidthOverflow: CGFloat { cellWidth * CGFloat(cellOverflow) }
    /// Current value clamped to the receiver's value bounds.
    private var clampedValue: CGFloat { value.clamped(to: bounds) }

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
        self._controlValue = value
        self.bounds = .init(uncheckedBounds: (CGFloat(bounds.lowerBound), CGFloat(bounds.upperBound)))
        self.step = CGFloat(step)
        self.snap = snap
        self.tick = tick
        self.editingChangedCallback = onEditingChanged
        self.formatter = formatter
    }

    // MARK: Rendering
    
    public var body: some View {
        let renderedValue: CGFloat, renderedOffset: CGSize

        (renderedValue, renderedOffset) = renderingValues()

        return FlexibleWidthContainer {
            ZStack(alignment: .init(horizontal: .center, vertical: self.verticalCursorAlignment)) {
                Ruler(cells: self.cells, step: self.step, markOffset: self.markOffset, bounds: self.bounds, formatter: self.formatter)
                    .equatable()
                    .animation(nil)
                    .modifier(InfiniteOffsetEffect(offset: renderedOffset, maxOffset: self.cellWidthOverflow))
                self.style.makeCursorBody()
            }
        }
        .modifier(InfiniteMarkOffsetModifier(renderedValue, step: step))
        .propagateWidth(ControlWidthPreferenceKey.self)
        .onPreferenceChange(MarkOffsetPreferenceKey.self, storeValueIn: $markOffset)
        .onPreferenceChange(ControlWidthPreferenceKey.self, storeValueIn: $controlWidth) {
            self.updateCellsIfNeeded()
        }
        .transaction {
            if $0.animation != nil { $0.animation = .easeIn(duration: 0.1) }
        }
        .onHorizontalDragGesture(initialTouch: firstTouchHappened,
                                 prematureEnd: panGestureEndedPrematurely,
                                 perform: horizontalDragAction(withValue:))
    }

    private func renderingValues() -> (CGFloat, CGSize) {
        let value: CGFloat
        let offset: CGSize

        switch self.state {
        case .flicking, .springing:
            if self.value != self.lastValueSet {
                self.animationTimer?.cancel()
                NextLoop { self.state = .idle }
                value = clampedValue ?? 0
                offset = self.offset(fromValue: value)
            } else {
                fallthrough
            }
        case .dragging, .stoppedFlick, .stoppedSpring:
            offset = dragOffset
            value = self.value(fromOffset: offset)
        case .animating:
            if self.value != lastValueSet {
                NextLoop { self.state = .idle }
                fallthrough
            }
            value = animatedValue
            offset = self.offset(fromValue: value)
        case .idle:
            value = clampedValue ?? 0
            offset = self.offset(fromValue: value)
        }

        return (value, offset)
    }
}

// MARK: Drag Gesture Management
extension SlidingRuler {

    /// Callback handling first touch event.
    private func firstTouchHappened() {
        switch state {
        case .flicking:
            cancelCurrentTimer()
            state = .stoppedFlick
        case .springing:
            cancelCurrentTimer()
            state = .stoppedSpring
        default: break
        }
    }

    /// Callback handling gesture premature ending.
    private func panGestureEndedPrematurely() {
        switch state {
        case .stoppedFlick:
            state = .idle
            snapIfNeeded()
        case .stoppedSpring:
            releaseRubberBand()
        default:
            break
        }
    }

    /// Composite callback passed to the horizontal drag gesture recognizer.
    private func horizontalDragAction(withValue value: HorizontalDragGestureValue) {
        switch value.state {
        case .began: horizontalDragBegan(value)
        case .changed: horizontalDragChanged(value)
        case .ended: horizontalDragEnded(value)
        default: return
        }
    }

    /// Callback handling horizontal drag gesture begining.
    private func horizontalDragBegan(_ value: HorizontalDragGestureValue) {
        editingChangedCallback(true)
        if state != .stoppedSpring {
            dragOffset = self.offset(fromValue: clampedValue ?? 0)
        }
        referenceOffset = dragOffset
        state = .dragging
    }

    /// Callback handling horizontal drag gesture updating.
    private func horizontalDragChanged(_ value: HorizontalDragGestureValue) {
        let newOffset = self.directionalOffset(value.translation.horizontal + referenceOffset)
        let newValue = self.value(fromOffset: newOffset)
        
        self.tickIfNeeded(dragOffset, newOffset)
        
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
        } else if abs(value.velocity) > 90 {
            self.applyInertia(initialVelocity: value.velocity)
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
    private func value(fromOffset offset: CGSize) -> CGFloat {
        self.directionalValue(-CGFloat(offset.width / cellWidth) * step)
    }

    /// Compute the ruler's offset from the given value.
    private func offset(fromValue value: CGFloat) -> CGSize {
        let width = -value * cellWidth / step
        return self.directionalOffset(.init(horizontal: width))
    }

    /// Sets the value.
    private func setValue(_ newValue: CGFloat) {
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
        let fractionalValue = step / CGFloat(fractions)

        guard delta < fractionalValue else { return }

        let animThreshold = step / 200
        let animation: Animation? = delta > animThreshold ? .easeOut(duration: 0.1) : nil

        dragOffset = offset(fromValue: nearest)
        withAnimation(animation) { self.value = nearest }
    }

    /// Returns the nearest value to snap on based on the `snap` property.
    private func nearestSnapValue(_ value: CGFloat) -> CGFloat {
        guard snap != .none else { return value }

        let t: CGFloat

        switch snap {
        case .unit: t = step
        case .half: t = step / 2
        case .fraction: t = step / CGFloat(fractions)
        default: fatalError()
        }

        let lower = (value / t).rounded(.down) * t
        let upper = (value / t).rounded(.up) * t
        let deltaDown = abs(value - lower).approximated()
        let deltaUp = abs(value - upper).approximated()

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
        cells = (-boundary...boundary).map { .init($0) }
    }
}

extension UIScrollView.DecelerationRate {
    static var ruler: Self { Self.init(rawValue: 0.9972) }
}

// MARK: Mechanic Simulation
extension SlidingRuler {

    private func applyInertia(initialVelocity: CGFloat) {
        func shiftOffset(by distance: CGSize) {
            let newOffset = directionalOffset(self.referenceOffset + distance)
            let newValue = self.value(fromOffset: newOffset)

            self.tickIfNeeded(self.dragOffset, newOffset)

            withoutAnimation {
                self.setValue(newValue)
                self.dragOffset = newOffset
            }
        }

        referenceOffset = dragOffset

        let rate = UIScrollView.DecelerationRate.ruler
        let totalDistance = Mechanic.Inertia.totalDistance(forVelocity: initialVelocity, decelerationRate: rate)
        let finalOffset = self.referenceOffset + .init(horizontal: totalDistance)

        state = .flicking

        if dragBounds.contains(finalOffset.width) {
            let duration = Mechanic.Inertia.duration(forVelocity: initialVelocity, decelerationRate: rate)

            animationTimer = .init(duration: duration, animations: { (progress, interval) in
                let distance =  CGSize(horizontal: Mechanic.Inertia.distance(atTime: progress, v0: initialVelocity, decelerationRate: rate))
                shiftOffset(by: distance)
            }, completion: { (completed) in
                if completed {
                    self.state = .idle
                    shiftOffset(by: .init(horizontal: totalDistance))
                    self.snapIfNeeded()
                    self.endDragSession()
                } else {
                    NextLoop { self.endDragSession() }
                }
            })
        } else {
            let allowedDistance = finalOffset.width.clamped(to: dragBounds) - self.referenceOffset.width
            let duration = Mechanic.Inertia.time(toReachDistance: allowedDistance, forVelocity: initialVelocity, decelerationRate: rate)
            animationTimer = .init(duration: duration, animations: { (progress, interval) in
                let distance =  CGSize(horizontal: Mechanic.Inertia.distance(atTime: progress, v0: initialVelocity, decelerationRate: rate))
                shiftOffset(by: distance)
            }, completion: { (completed) in
                if completed {
                    shiftOffset(by: .init(horizontal: allowedDistance))
                    let remainingVelocity = Mechanic.Inertia.velocity(atTime: duration, v0: initialVelocity, decelerationRate: rate)
                    self.applyInertialRubber(remainingVelocity: remainingVelocity)
                    self.endDragSession()
                } else {
                    NextLoop { self.endDragSession() }
                }
            })
        }
    }

    private func applyInertialRubber(remainingVelocity: CGFloat) {
        let duration = Mechanic.Spring.duration(forVelocity: abs(remainingVelocity), displacement: 0)
        let targetOffset = dragOffset.width.nearestBound(of: dragBounds)

        state = .springing

        animationTimer = .init(duration: duration, animations: { (progress, interval) in
            let delta = Mechanic.Spring.value(atTime: progress, v0: remainingVelocity, displacement: 0)
            self.dragOffset = .init(horizontal: targetOffset + delta)
        }, completion: { (completed) in
            if completed {
                self.dragOffset = .init(horizontal: targetOffset)
                self.state = .idle
            }
        })
    }

    /// Applies rubber effect to an off-range offset.
    private func applyRubber(to offset: CGSize) -> CGSize {
        let dragBounds = self.dragBounds
        guard !dragBounds.contains(offset.width) else { return offset }
        
        let tx = offset.width
        let limit = tx.clamped(to: dragBounds)
        let delta = abs(tx - limit)
        let factor: CGFloat = tx - limit < 0 ? -1 : 1
        let d = controlWidth ?? 0
        let c = CGFloat(0.55)
        let rubberDelta = (1 - (1 / ((c * delta / d) + 1))) * d * factor
        let rubberTx = limit + rubberDelta
        
        return .init(horizontal: rubberTx)
    }

    /// Animates an off-range offset back in place
    private func releaseRubberBand() {
        let targetOffset = dragOffset.width.clamped(to: dragBounds)
        let delta = dragOffset.width - targetOffset
        let duration = Mechanic.Spring.duration(forVelocity: 0, displacement: abs(delta))

        state = .springing

        animationTimer = .init(duration: duration, animations: { (progress, interval) in
            let newDelta = Mechanic.Spring.value(atTime: progress, v0: 0, displacement: delta)
            self.dragOffset = .init(horizontal: targetOffset + newDelta)
        }, completion: { (completed) in
            if completed {
                self.dragOffset = .init(horizontal: targetOffset)
                self.state = .idle
            }
        })
    }

    /// Stops the current animation and cleans the timer.
    private func cancelCurrentTimer() {
        animationTimer?.cancel()
        animationTimer = nil
    }

    private func cleanTimer() {
        animationTimer = nil
    }
}



// MARK: Tick Management
extension SlidingRuler {
    private func boundaryMet() {
        let fg = UIImpactFeedbackGenerator(style: .rigid)
        fg.impactOccurred(intensity: 0.667)
    }

    private func tickIfNeeded(_ offset0: CGSize, _ offset1: CGSize) {
        let width0 = offset0.width, width1 = offset1.width

        let dragBounds = self.dragBounds
        guard dragBounds.contains(width0), dragBounds.contains(width1),
            !width0.isBound(of: dragBounds), !width1.isBound(of: dragBounds) else { return }
        
        let t: CGFloat
        switch tick {
        case .unit: t = cellWidth
        case .half: t = hasHalf ? cellWidth / 2 : cellWidth
        case .fraction: t = cellWidth / CGFloat(fractions)
        case .none: return
        }
        
        if width1 == 0 ||
            (width0 < 0) != (width1 < 0) ||
            Int((width0 / t).approximated()) != Int((width1 / t).approximated()) {
            valueTick()
        }
    }
    
    private func valueTick() {
        let fg = UIImpactFeedbackGenerator(style: .light)
        fg.impactOccurred(intensity: 0.5)
    }
}

