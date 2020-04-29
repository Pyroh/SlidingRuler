import SwiftUI
import SmoothOperators

@available(iOS 13.0, *)
struct SlidingRuler<V>: View where V: BinaryFloatingPoint, V.Stride: BinaryFloatingPoint {
    @Environment(\.slidingRulerStyle) private var style
    @Environment(\.slidingRulerStyle.cellWidth) private var cellWidth
    @Environment(\.slidingRulerStyle.cursorAlignment) private var verticalCursorAlignment
    
    @Environment(\.slideRulerCellOverflow) private var cellOverflow
    @Environment(\.layoutDirection) private var layoutDirection
    
    @Binding private var value: V
    private let bounds: ClosedRange<V>
    private let step: V
    private let stickyMark: StickyMark
    private let tick: Tick
    private let editingChangedCallback: (Bool) -> ()
    private let formatter: NumberFormatter?
    
    @State private var controlSize: CGSize?
    @State private var slidingRuleSize: CGSize?
    
    @State private var cells: [SlidingRuleCell<V>] = []
    
    @State private var state: SlidingRulerState = .idle
    @State private var animatedValue: V = .zero
    
    @State private var referenceOffset: CGSize?
    @State private var dragOffset: CGSize = .zero
    
    @State private var inertialTimer: VSynchedTimer? = nil
    @State private var lastValueSet: V = .zero
    @State private var markOffset: Double = .zero
    
    private var dragBounds: ClosedRange<CGFloat> {
        (-CGFloat(bounds.upperBound) * cellWidth / CGFloat(step))...(-CGFloat(bounds.lowerBound) * cellWidth / CGFloat(step))
    }
    private var shouldReleaseRubberBand: Bool { !dragBounds.contains(dragOffset.width) }
    private var clampedValue: V { value.clamped(to: bounds) }
    private var halfStep: V { step / 2 }
    private var tenthStep: V { step / 10 }
    
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
    
    init(value: Binding<V>,
         in bounds: ClosedRange<V> = -V.infinity...V.infinity,
         step: V.Stride = 1,
         stickyMark: StickyMark = .none,
         tick: Tick = .none,
         onEditingChanged: @escaping (Bool) -> () = { _ in },
         formatter: NumberFormatter? = nil) {
        self._value = value
        self.bounds = bounds
        self.step = V(step)
        self.stickyMark = stickyMark
        self.tick = tick
        self.editingChangedCallback = onEditingChanged
        self.formatter = formatter
    }
    
    var body: some View {
        switch self.state {
        case .animating:
            NextLoop { self.state = .idle }
        case .flicking:
            NextLoop {
                if self.value != self.lastValueSet {
                    self.inertialTimer?.cancel()
                    self.state = .idle
                }
            }
        default: break
        }
        
        return GeometryReader { proxy in
            ZStack(alignment: .init(horizontal: .center, vertical: self.verticalCursorAlignment)) {
                SlidingRule(cells: self.cells, step: Double(self.step), markOffset: self.markOffset, bounds: self.bounds, formatter: self.formatter)
                    .equatable()
                    .background(GeometryReader { proxy in
                        Color.clear
                            .preference(key: SlidingRuleSizePreferenceKey.self, value: proxy.size)
                    })
                    .animation(nil)
                    .modifier(InfiniteOffsetEffect(offset: self.effectiveOffset, maxOffset: 240))
                self.style.makeCursorBody()
            }
            .frame(width: proxy.size.width)
            .clipped()
            .preference(key: ControlSizePreferenceKey.self, value: proxy.size)
            .fixedSize(horizontal: false, vertical: true)
        }
        .onHorizontalDragGesture(initialTouch: firstTouchHappened, perform: horizontalDragAction(withValue:))
        .modifier(InfiniteMarkOffsetModifier(effectiveValue, step: step))
        .onPreferenceChange(MarkOffsetPreferenceKey.self, perform: { self.markOffset = $0})
        .onPreferenceChange(ControlSizePreferenceKey.self, perform: {
            self.controlSize = $0
            self.updateCellsIfNeeded()
        })
            .onPreferenceChange(SlidingRuleSizePreferenceKey.self, perform: {
                self.slidingRuleSize = $0
            })
            .transaction({
                if $0.animation != nil && self.state == .idle { $0.animation = .easeIn(duration: 0.1) }
            })
            .frame(height: self.slidingRuleSize?.height)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    // MARK: Drag Gesture Management
    
    private func horizontalDragAction(withValue value: HorizontalDragGestureValue) {
        switch value.state {
        case .began: horizontalDragBegan(value)
        case .changed: horizontalDragChanged(value)
        case .ended: horizontalDragEnded(value)
        default: return
        }
    }
    
    private func firstTouchHappened() {
        if state != .dragging {
            inertialTimer?.cancel()
            state = .idle
        }
    }
    
    private func horizontalDragBegan(_ value: HorizontalDragGestureValue) {
        if referenceOffset == nil {
            editingChangedCallback(true)
            referenceOffset = effectiveOffset
            state = .dragging
        }
    }
    
    private func horizontalDragChanged(_ value: HorizontalDragGestureValue) {
        let newOffset = self.directionalOffset(value.translation.horizontal + (referenceOffset ?? .zero))
        let newValue = self.value(fromOffset: newOffset)
        
        self.tickIfNeeded(dragOffset.width, newOffset.width)
        
        withoutAnimation {
            self.setValue(newValue, via: \.$value)
            dragOffset = self.applyRubber(to: newOffset)
        }
    }
    
    private func horizontalDragEnded(_ value: HorizontalDragGestureValue) {
        if shouldReleaseRubberBand {
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
    
    private func endDragSession() {
        referenceOffset = nil
        self.editingChangedCallback(false)
    }
    
    // MARK: Value Management
    
    private func value(fromOffset offset: CGSize) -> V {
        -V(offset.width / cellWidth) * step
    }
    
    private func offset(fromValue value: V) -> CGSize {
        let width = CGFloat(-value * V(cellWidth) / step)
        return .init(horizontal: width)
    }
    
    private func setValue(_ newValue: V, via key: KeyPath<Self, Binding<V>>) {
        func get() -> V { self[keyPath: key].wrappedValue }
        func set(_ value: V) { self[keyPath: key].wrappedValue = value }
        
        let clampedValue = newValue.clamped(to: bounds)
        
        if clampedValue.isBound(of: bounds) && !get().isBound(of: self.bounds) {
            self.boundaryMet()
        }
        
        if lastValueSet != clampedValue { lastValueSet = clampedValue }
        if get() != clampedValue { set(clampedValue) }
    }
    
    private func snapIfNeeded() {
        let nearest = self.nearestValue(self.value)
        if  nearest != value {
            if abs(nearest - value) > 0.005 {
                withAnimation(.easeOut(duration: 0.1)) { self.value = nearest }
            } else {
                withoutAnimation { self.value = nearest }
            }
        }
    }
    
    private func nearestValue(_ value: V) -> V {
        if case .none = stickyMark { return value }
        let t: V
        
        switch stickyMark.bound {
        case .any, .tenth: t = tenthStep
        case .half: t = halfStep
        case .unit: t = step
        }
        
        switch stickyMark {
        case .lower(_): return (value / t).rounded(.down) * t
        case .upper(_): return (value / t).rounded(.up) * t
        case .nearest:
            let lower = (value / t).rounded(.down) * t
            let upper = (value / t).rounded(.up) * t
            let deltaDown = abs(value - lower)
            let deltaUp = abs(value - upper)
            return deltaDown < deltaUp ? lower : upper
        default: fatalError()
        }
    }
    
    func directionalValue<T: Numeric>(_ value: T) -> T {
        value * (layoutDirection == .rightToLeft ? -1 : 1)
    }
    
    func directionalOffset(_ offset: CGSize) -> CGSize {
        let width = self.directionalValue(offset.width)
        return .init(width: width, height: offset.height)
    }
    
    // MARK: Control Update
    
    private func updateCellsIfNeeded() {
        guard let controlWidth = controlSize?.width else { return }
        let count = (Int(ceil(controlWidth / cellWidth)) + 4).nextOdd()
        if count != cells.count { self.populateCells(count: count) }
    }
    
    private func populateCells(count: Int) {
        let boundary = count.previousEven() / 2
        cells = (-boundary...boundary).map { SlidingRuleCell(mark: V($0)) }
    }
    
    // MARK: Physic Simulation
    
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
            let newOffset = self.directionalOffset(translation + (self.referenceOffset ?? .zero))
            let newValue = self.value(fromOffset: newOffset)
            
            self.tickIfNeeded(self.dragOffset.width, newOffset.width)
            
            withoutAnimation {
                self.setValue(newValue, via: \.$value)
                self.dragOffset = self.applyRubber(to: newOffset)
            }
            
            if !self.shouldReleaseRubberBand {
                speed = speed - CGFloat(friction * timeFrame)
            } else {
                speed = speed - CGFloat(bounceFriction * timeFrame)
            }
            
            if speed <= 0 { self.inertialTimer?.stop() }
        }, completion: { (completed) in
            if self.shouldReleaseRubberBand {
                self.releaseRubberBand()
            } else if completed {
                self.state = .idle
                self.snapIfNeeded()
            }
            
            self.endDragSession()
        })
    }
    
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
    
    private func releaseRubberBand() {
        self.animatedValue = self.value(fromOffset: effectiveOffset)
        self.state = .animating
        NextLoop {
            withAnimation(.spring(response: 0.666, dampingFraction: 1.0)) {
                self.animatedValue = self.value
            }
        }
    }
    
    // MARK: Tick Management
    
    private func boundaryMet() {
        let fg = UIImpactFeedbackGenerator(style: .rigid)
        fg.impactOccurred(intensity: 0.667)
    }
    
    private func tickIfNeeded(_ offset0: CGFloat, _ offset1: CGFloat) {
        guard dragBounds.contains(offset0) && dragBounds.contains(offset1),
            !offset0.isBound(of: dragBounds) && !offset1.isBound(of: dragBounds) else { return }
        
        let t: CGFloat
        switch tick {
        case .unit: t = cellWidth
        case .half: t = cellWidth / 2
        case .tenth: t = cellWidth / 10
        case .none: return
        }
        
        if offset1 == 0 || (offset0 < 0) != (offset1 < 0) || Int(offset0 / t) != Int(offset1 / t) {
            valueTick()
        }
    }
    
    private func valueTick() {
        let fg = UIImpactFeedbackGenerator(style: .light)
        fg.impactOccurred(intensity: 0.5)
    }
}

struct SlideRulerPresenter: View {
    static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        
        return f
    }()
    
    @State var value: CGFloat = .zero
    
    var body: some View {
        VStack {
            Rectangle().foregroundColor(.orange).frame(size: .init(width: 100, height: 50))
                .overlay(Rectangle().stroke(Color.blue, lineWidth: 3))
                .offset(x: value * 80, y: 0)
            Form {
                SlidingRuler(value: $value, in: -2...10, stickyMark: .nearest, tick: .half)
                    .padding(.vertical)
                Slider(value: $value, in: -2...2)
            }
            HStack(spacing: 20) {
                Button(action: {
                    withAnimation { self.value <- { $0- } }
                }) {
                    Image(systemName: "minus.circle.fill")
                }
                Button(action: {
                    withAnimation { self.value = 0 }
                }) {
                    Image(systemName: "xmark.circle.fill")
                }
                Button(action: {
                    withAnimation { self.value <- { $0+ } }
                }) {
                    Image(systemName: "plus.circle.fill")
                }
            }
            .font(.largeTitle)
            .padding()
            HStack {
                ForEach([-123, -12.3, -1.23, 1.23, 12.3, 123], id: \.self) { value in
                    Button(Self.formatter.string(for: value) ?? "Er") { withAnimation { self.value = value } }
                }
            }
        }
        .padding(.top, 33.334)
    }
}

struct SlideRuler_Previews: PreviewProvider {
    static var previews: some View {
        SlideRulerPresenter()
            .environment(\.colorScheme, .light)
    }
}
