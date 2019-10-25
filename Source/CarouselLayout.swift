/*
	CarouselLayout.swift
	T0Carousel

	Created by Torsten Louland on 07/02/2018.

	MIT License

	Copyright (c) 2018 Torsten Louland

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
*/

import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import T0Utils


class Log : T0Logging {}


/*
	CarouselLayout presents cells like a deck of cards with a number spread out and the remainder
	in the pack, e.g. the top or face card is completely visible, the second card is behind and
	offset from the face card, likewise the third is offset and behind the second, etc. and this
	repeats for a number of cards until the pack is reached, i.e. the remainder of the cards in one
	pile with only the top one seen. When there is no spread, the top of the pack is the face card
	and is the only card visible.

	Parameters allow control of the number of spread cards at any time, the size of the pack
	relative to the size of the face card and hence the sizes and offsets of intermediate cards in
	the spread. The cards are spread along a locus, wherein the centre of each card lies on a Bézier
	curve. You can specify the control points of the bezier curve, so affecting the offset sequence
	for the spread. The default is that the Bézier has evenly spaced control points and hence
	behaves in a linear fashion. The position of the top card and the pack can also be specified in
	normalized coordinates, wherein 0,0 will place a card so that it sits in the top left corner of
	the available area, i.e. edges flush, and 1,1 will position it flush in the bottom right.

	When a card in the spread is scrolled towards the top, the face card is moved off in progression
	and quickly faded out, then moved to fade in and rejoin the back of the pack.

	The face card is considered to be the selected card, and selecting a different card moves it to
	the face position.

*/
public class CarouselLayout : UICollectionViewLayout
{
	public struct Params
	{
		public var spreadCount:			Int = 4
		public var faceSize:			CGSize = .zero
		public var facePosition:		CGPoint = CGPoint.init(x: 0, y: 1)
		public var packScale:			CGFloat = 0.5
		public var packPosition:		CGPoint = CGPoint.init(x: 1, y: 0)
		public var locusControlPoints:	[CGFloat] = [0,0, 1.0/3,1.0/3, 2.0/3,2.0/3, 1,1]
		public var returnOvershoot:		CGFloat = 0.5
		// for debugging:
		public var showLocus:			Bool = false

		public init(){}
	}
	// MARK:-
	public struct Progression
	{
		public let values:				[CGFloat]
		public let loopback:			Loopback
		/// Loopback describes behaviour when looping back from last value to first value
		public enum Loopback {
			/// `continuous` means there is a step between last and first. When passing last, the progression returns to first via interpolated intermediate values.
			case continuous
			/// `discrete` means that there is no step between first and last. When reaching last, the progression immediately returns to first with no intervening value.
			case discrete
			func normalise(position: CGFloat, within count: Int) -> CGFloat {
				let steps = CGFloat(self == .continuous ? count : count - 1)
				let normalised = rotate(position, by: 0, within: steps)
				return normalised
			}
		}
		public init() { values = [] ; loopback = .continuous }
		public init(_ v: [CGFloat], _ l: Loopback = .continuous) { values = v ; loopback = l }
		public func value(at position: CGFloat) -> CGFloat {
			let posn = loopback.normalise(position: position, within: values.count)
			let n = Int(trunc(posn)), m = (n + 1) % values.count
			let t1 = posn - CGFloat(n)
			let t0 = 1 - t1
			let v0 = values[n]
			let v1 = values[m]
			let v = t0 * v0 + t1 * v1
			return v
		}
		public func values(from position: CGFloat, forwards: Bool) -> [CGFloat] {
			let posn = loopback.normalise(position: position, within: values.count)
			var n = Int(trunc(posn))
			var t = posn - CGFloat(n)
			if abs(1 - t) < 1e-10 {
				t = 0 ; n += 1
			} else if abs(t) < 1e-10 {
				t = 0
			}
			var v = [CGFloat]()
			if t == 0 {
				let i = values.startIndex.advanced(by: n)
				v.append(contentsOf: values[ i ..< values.endIndex ])
				v.append(contentsOf: values[ values.startIndex ..< i ])
				return v
			}
			v = ( 0 ..< values.count ).map { self.value(at: CGFloat($0) + position) }
			return v
		}
	}
	/// Locus describes a single closed path using sequence of Bézier curves
	public struct Locus
	{
		/// Must contain 3n + 1 Bézier control points, and the last point must replicate the first.
		public var points:				[CGPoint]
		public init(count: Int = 0)	{ points = [CGPoint](repeating: .zero, count: count) }
		public enum ControlPoint : Int	{ case A = 0, B, C, D }
		public static func index(t: Int, cp: ControlPoint = .A) -> Int {
			return t * 3 + cp.rawValue
		}
		public subscript(t: Int, cp: ControlPoint) -> CGPoint {
			get { return points[Locus.index(t: t, cp: cp)] }
			set { points[Locus.index(t: t, cp: cp)] = newValue }
		}
		public enum Sense { case entering, leaving }
		public func vector(_ sense: Sense,_ t: Int, _ cp: ControlPoint) -> CGPoint {
			var i = Locus.index(t: t, cp: cp)
			guard i < points.count else { return .zero }
			var j = i
			switch sense {
				case .entering:	i = rotate(i, by: -1, within: points.count)
				case .leaving:	j = rotate(j, by: +1, within: points.count)
			}
			if i > j, points[i] == points[j] { // wrap around with closed path
				switch sense { // skip the repeated point
					case .entering:	i = rotate(i, by: -2, within: points.count)
					case .leaving:	j = rotate(j, by: +2, within: points.count)
				}
			}
			let a = points[i], b = points[j]
			return b - a
		}
		public var asCGPath: CGPath {
			let path = CGMutablePath()
			guard points.count > 3
			else { return path }
			var i = points.startIndex
			path.move(to: points[i])
			var remaining = points.count / 3
			while remaining > 0 {
				let b = points[ i.advanced(by: 1) ]
				let c = points[ i.advanced(by: 2) ]
				let d = points[ i.advanced(by: 3) ]
				path.addCurve(to: d, control1: b, control2: c)
				i = i.advanced(by: 3)
				remaining -= 1
			}
			path.closeSubpath()
			return path
		}
		public func path(from t: Int, forwards: Bool) -> CGPath {
			return self.rotated(startingAt: t, forwards: forwards).asCGPath
		}
		public func rotated(startingAt t: Int, forwards: Bool = true) -> Locus {
			var locus = Locus()
			let n = Locus.index(t: t)
			guard t >= 0, n < points.count, points.count % 3 == 1
			else { return locus }
			var i = points.startIndex.advanced(by: n)
			locus.points.append(points[i])
			let increment = forwards ? 1 : -1
			let wrapAt = forwards ? points.endIndex.advanced(by: -1) : points.startIndex
			let wrapTo = forwards ? points.startIndex : points.endIndex.advanced(by: -1)
			var remaining = points.count / 3
			while remaining > 0 {
				if i == wrapAt {
					i = wrapTo
				}
				locus.points.append(points[ i.advanced(by: increment * 1) ])
				locus.points.append(points[ i.advanced(by: increment * 2) ])
				locus.points.append(points[ i.advanced(by: increment * 3) ])
				i = i.advanced(by: increment * 3)
				remaining -= 1
			}
			return locus
		}
	}
	// MARK:-
	struct WorkingParams
	{
		var spreadCount:		Int = 0
		var faceRect:			CGRect = .zero
		var packRect:			CGRect = .zero
		var locus:				Locus = Locus()
		var scaleProgression:	Progression = Progression()
		var alphaProgression:	Progression = Progression()
		var evaluatedForSize:	CGSize = .zero
		func valid(for sz: CGSize) -> Bool			{ return evaluatedForSize == sz && sz != .zero }
		mutating func invalidate()					{ evaluatedForSize = .zero }
		init(){ }
	}
	// MARK:-
	// environment
	public var availableArea:			CGSize				{ get { return collectionViewContentSize } }
	public var itemCount:				Int					{ get { return collectionView?.numberOfItems(inSection: 0) ?? 0 } }
	private var selecteeIndex:	Int {
		get {
			return collectionView?.indexPathsForSelectedItems?.first?.item ?? 0
		}
		set {
			guard let cv = collectionView else { return }
			let item = rotate(newValue, by: 0, within: itemCount)
			let ip = IndexPath(item: item, section: 0)
			let show = cv.delegate?.collectionView?(cv, shouldSelectItemAt: ip)
			if case .some(false) = show { return }
			cv.selectItem(at: ip, animated: false, scrollPosition: [])
			cv.delegate?.collectionView?(cv, didSelectItemAt: ip)
		}
	}
	// params
	public var faceCardSize:	CGSize				{ get { return params.faceSize }
													  set { params.faceSize = newValue } }
	public var params:			Params = Params()	{ didSet { _wp.invalidate() ; _ = wp } }
	// working values
	private var _wp =			WorkingParams()		{ didSet {
														if oldValue != _wp { invalidate() }
														if showLocus(params.showLocus ? _wp.locus : nil) { invalidate() }
													} }
	private var wp:				WorkingParams		{ if !_wp.valid(for: availableArea) {
														  _wp = generateWorkingParams() }
													  return _wp }
	var transitionalOffset:		CGFloat = 0

	// host
	var collectionViewObserver:	NSKeyValueObservation? = nil
	// debug
	public var locusView:		LocusView? = nil

	// interraction: taps, panning
	var tapRecogniser =			UITapGestureRecognizer()
	var panRecogniser =			UIPanGestureRecognizer()
	public var gp =				GestureParams()
	public var gh =				GestureHandling()

	// MARK: -

	public override init() {
		super.init()
		completeInit()
	}

	public required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		completeInit()
	}

	func completeInit() {
		tapRecogniser.addTarget(self, action: #selector(self.tapRecognised(by:)))
		panRecogniser.addTarget(self, action: #selector(self.panRecognised(by:)))
		collectionViewObserver = observe(\.collectionView, options: [.old,.new])
			{ this, values in
				let old = values.oldValue as? UICollectionView
				let new = values.newValue as? UICollectionView
				this.collectionViewChanged(from: old, to: new)
			}
	}

	func collectionViewChanged(from: UICollectionView?, to: UICollectionView?) {
		recogniserHost = to
	}
}



// MARK: - Configuration calculations
extension CarouselLayout
{
	func generateWorkingParams() -> WorkingParams {
		var wp = WorkingParams()
		guard
			collectionView != nil,
			availableArea != .zero,
			itemCount > 0
		else { return wp }

		let spreadCount = max(0, min(params.spreadCount, itemCount - 1))
		let visibleCount = spreadCount + 1
		let availableSize = availableArea
		let faceWidth	= faceCardSize.width > 0
						? min(faceCardSize.width, availableSize.width)
						: max(2, 2 * availableSize.width / CGFloat(spreadCount + 2))
		let faceHeight	= faceCardSize.height > 0
						? min(faceCardSize.height, availableSize.height)
						: max(2, 2 * availableSize.height / CGFloat(spreadCount + 2))
		let faceSize = CGSize(width: faceWidth, height: faceHeight)

		wp.evaluatedForSize = availableSize

		wp.spreadCount = spreadCount

		var faceRect = CGRect(faceSize)
		var packRect = faceRect
		packRect.size = packRect.size * params.packScale

		faceRect.origin = params.facePosition * (availableSize - faceRect.size)
		packRect.origin = params.packPosition * (availableSize - packRect.size)

		wp.faceRect = faceRect
		wp.packRect = packRect


		if spreadCount == 0 {
			// diminished case: single item at single point
			wp.locus = Locus(count: 0)
			wp.locus.points.removeAll()
			wp.locus.points.append(faceRect.center)
			wp.scaleProgression = Progression([1])
			wp.alphaProgression = Progression([1])
			return wp
		}

		var scales: [CGFloat] = ( 0 ... spreadCount ).map {
			let t1 = CGFloat($0) / CGFloat(spreadCount), t0 = 1 - t1
			return t0 * 1.0 + t1 * params.packScale
		}
		scales.append(contentsOf: [CGFloat](repeating: params.packScale, count: itemCount - scales.count) )
		wp.scaleProgression = Progression(scales)

		var alpha = [CGFloat]()
		alpha.append(contentsOf: [CGFloat](repeating: 1, count: min(spreadCount + 2, itemCount)) )
		alpha.append(contentsOf: [CGFloat](repeating: 0, count: itemCount - alpha.count) )
		wp.alphaProgression = Progression(alpha)

		// We subdivide the locus by the number of items in the spread, and add a single bezier
		// for the return, then add a bezier for each item in the pack. This means that the
		// traversal between adjacent positions is exactly one bezier, wherever the item is.
		var points = [CGPoint]()
		let locusBezier = stride(from: 0, to: params.locusControlPoints.count, by: 2).map {
			CGPoint(x: params.locusControlPoints[$0], y: params.locusControlPoints[$0+1])
		}
		divide(bezier: locusBezier.dropFirst(0), by: spreadCount, into: &points)
		// remember that t=0 is the face, locusControlPoints extends from face to pack, and adding
		// the subdivided locusControlPoints means that we are now at the pack and t=spreadCount.
		// We need to add trivial beziers for the remaining items hidden in the pack before we add
		// the return path.
		let endPoint = points[points.endIndex.advanced(by: -1)]
		let startPoint = points[points.startIndex]
		let hiddenCount = itemCount - visibleCount
		if hiddenCount > 0 {
			let staticBeziers: [CGPoint] = .init(repeating: endPoint, count: hiddenCount * 3)
			points.append(contentsOf: staticBeziers)
		}
		// now the return path
		let b = endPoint + (locusBezier[3] - locusBezier[2]) * params.returnOvershoot
		let c = startPoint + (locusBezier[0] - locusBezier[1]) * params.returnOvershoot
		let d = locusBezier[0]
		points.append(contentsOf: [b, c, d])
		wp.locus = Locus(count: 0)
		wp.locus.points = points

		// Now scale the locus to run from faceRect anchor to packRect anchor
		var transform = CGAffineTransform.identity
		let scaleTo = packRect.center - faceRect.center
		transform = transform.translatedBy(x: faceRect.center.x, y: faceRect.center.y)
		transform = transform.scaledBy(x: scaleTo.x, y: scaleTo.y)
		wp.locus.points = wp.locus.points.map { $0.applying(transform) }

		// done
		return wp
	}

	func invalidate() {
		invalidateLayout()
	}

	func ordinal(at ip: IndexPath) -> Int {
		return ip.section == 0 ? rotate(ip.item, by: -selecteeIndex, within: itemCount) : itemCount
	}

	func indexPath(at position: CGFloat) -> IndexPath {
		let itemF = rotate(position, by: CGFloat(selecteeIndex), within: CGFloat(itemCount))
		let item = Int(floor(itemF))
		return IndexPath(item: item, section: 0)
	}

	func zIndexAtOrdinal(_ ordinal: Int) -> Int {
		return itemCount - ordinal
	}

	func ordinalAtZIndex(_ zIndex: Int) -> Int {
		return itemCount - zIndex
	}
}



// MARK: - UICollectionLayout functions
extension CarouselLayout
{
	open override func prepare() {
		super.prepare()
	}

	open override var collectionViewContentSize: CGSize {
		return collectionView?.frame.size ?? .zero
	}

	open override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
		return true
	}

	open override class var layoutAttributesClass: AnyClass {
		return CarouselCellLayoutAttributes.self
	}

	open override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
		var array = [UICollectionViewLayoutAttributes]()
		for item in 0..<itemCount {
			let indexPath = IndexPath(item: item, section: 0)
			if	let frame = frame(at: indexPath),
				frame.intersects(rect),
				let attributes = layoutAttributesForItem(at: indexPath) {
				array.append(attributes)
			}
		}
		return array
	}

	open override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
		let ordinalBase = CGFloat(self.ordinal(at: indexPath))
		let position = rotate(ordinalBase, by: transitionalOffset, within: CGFloat(itemCount))
		return layoutAttributes(at: position, for: indexPath)
	}
}



// MARK: - Item layout
extension CarouselLayout
{
	func layoutAttributes(at position: CGFloat, for indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
		guard
			let attributesType = type(of: self).layoutAttributesClass as? CarouselCellLayoutAttributes.Type,
			itemCount > 0,
			let frame = self.frame(at: position)
		else { return nil }
		let attributes = attributesType.init(forCellWith: indexPath)
		let ordinal = Int(floor(position))
		let partial = position - CGFloat(ordinal)

		attributes.frame = frame
		attributes.zIndex = zIndexAtOrdinal(ordinal)
		// We show the spread, the top two cards of the pack (the one underneath is ready to be
		// revealed), and the card returning to the pack; the rest are hidden.
		attributes.isHidden = ordinal > wp.spreadCount + 1 && ordinal < itemCount - 2
		attributes.alpha = 1
		if ordinal == itemCount - 1 {
			// We fade the returning card out in the first quarter of its travel and fade it back in
			// in the last quarter of its travel
			attributes.alpha = max(0, 1 - abs(partial * 4))
		}
		var overlayAlpha: CGFloat = 0 // we show info overlays for the top card
		if ordinal == itemCount - 1 {
			overlayAlpha = attributes.alpha
		} else if position < CGFloat(wp.spreadCount) {
			overlayAlpha = max(0, 1 - position)
		}
		attributes.overlayAlpha = overlayAlpha
		// We avoid hide/show at the same time as alpha-->0/1 because it can cause animation glitches
		attributes.overlayHidden = ordinal > 1 && ordinal < itemCount - 1
		attributes.shadow = ordinal <= wp.spreadCount

		return attributes
	}

	func frame(at position: CGFloat) -> CGRect? {
		let ordinal = Int(floor(position))
		let partial = position - CGFloat(ordinal)

		var frame = wp.faceRect

		if ordinal == itemCount - 1 {
			// partial==0 ==> at pack (t=1), partial==1 ==> at face (t=4)
		//	let t = 1.0 + 3.0 * partial
			// We increase the card size when it comes off the top (partial= 1..0.75), but then set
			// it to pack size when it is rejoining the pack
			if partial < 0.5 {
				// for partial: 0..<0.5
				frame.size = wp.packRect.size
			//	frame.origin = pointAt(t: t, onBezierPath: wp.locus.points.dropFirst(0)) ?? .zero
				frame.center = pointAt(t: position, onBezierPath: wp.locus.points.dropFirst(0)) ?? .zero
			} else {
				// for partial: 0.5...1.0
				// continue with same scaling when leaving the top
				let mix = (1 - partial) * 2 // 1->0  <-- (partial: 0.5->1)
				//		/ (CGFloat(wp.spreadCount) + 1)
				frame.size = wp.packRect.size * mix + frame.size * (1.0 - mix)
			//	frame.origin = pointAt(t: t, onBezierPath: wp.locus.points.dropFirst(0)) ?? .zero
				frame.center = pointAt(t: position, onBezierPath: wp.locus.points.dropFirst(0)) ?? .zero
			}
		} else if position < CGFloat(wp.spreadCount) && wp.spreadCount > 0 {
			let mix = position / CGFloat(wp.spreadCount)
			frame.size = wp.packRect.size * mix + frame.size * (1.0 - mix)
		//	frame.origin = pointAt(t: mix, onBezierPath: wp.locus.points.dropFirst(0)) ?? .zero
			frame.center = pointAt(t: position, onBezierPath: wp.locus.points.dropFirst(0)) ?? .zero
		} else {
			frame = wp.packRect
		}

		frame = frame.integralOnScreen()

		return frame
	}

	func frame(at indexPath: IndexPath) -> CGRect? {
		let ordinalBase = CGFloat(self.ordinal(at: indexPath))
		let position = rotate(ordinalBase, by: transitionalOffset, within: CGFloat(itemCount))
		return frame(at: position)
	}
}



// MARK: -
/*
	CarouselCellLayoutAttributes adds extra properties for cells organised by a CarouselLayout. It
	is up to the actual cell class whether these are used.
	- overlays: as the cells are stacked and obscure ones behind, only the edge of the background
	of an obscured cell will be visible; therefore, the overlayAlpha and overlayHidden
	attributes allow any overlayed information to be faded out and hidden when it will not be
	usably visible
	- shadow: as shadow is usually partially transparent when used, use this property to switch off
	shadow for cells that are stacked coincidently, so as to avoid accumulated heavy shadow.
*/
open class CarouselCellLayoutAttributes : UICollectionViewLayoutAttributes
{
	public var overlayAlpha:	CGFloat = 0.0
	public var overlayHidden:	Bool = true
	public var shadow:				Bool = false

	open override func copy(with zone: NSZone? = nil) -> Any {
		let copy = super.copy(with: zone)
		if let attr = copy as? CarouselCellLayoutAttributes {
			attr.overlayAlpha = overlayAlpha
			attr.overlayHidden = overlayHidden
			attr.shadow = shadow
		}
		return copy
	}

	open override func isEqual(_ object: Any?) -> Bool {
		if	super.isEqual(object),
			let attr = object as? CarouselCellLayoutAttributes,
			attr.overlayAlpha == overlayAlpha,
			attr.overlayHidden == overlayHidden,
			attr.shadow == shadow
		{
			return true
		}
		return false
	}
}



// MARK: - Tap and Pan
extension CarouselLayout
{
	public struct GestureHandling {
		public var animateSelection:		Bool = false
		public var animateBounds:			Bool = false
		public var animateAlpha:			Bool = false
		public var bypassApply:				Bool = false
		public var verbose:					Bool = false
		public var selectDuration:			TimeInterval = 2.0
		public init() {
			animateSelection = false
			animateBounds = false
			animateAlpha = false
			bypassApply = false
			verbose = false
			selectDuration = 2.0
		}
		public init?(_ jso: AnyJSONObject) {
			guard case .dictionary(let d) = jso else { return nil }
			animateSelection = d["animateSelection"]?.asBool ?? false
			animateBounds = d["animateBounds"]?.asBool ?? false
			animateAlpha = d["animateAlpha"]?.asBool ?? false
			bypassApply = d["bypassApply"]?.asBool ?? false
			verbose = d["verbose"]?.asBool ?? false
			selectDuration = d["selectDuration"]?.asDouble ?? 2.0
		}
	}

	public struct GestureParams {
		public var animator:				UIViewPropertyAnimator? = nil
		public var selecteeIndexAt:			(animationStart: Int, animationEnd: Int) = (0,0)
	}

	enum Gesture { case tap, pan_start, pan_release(speed: CGFloat) }

	var recogniserHost: UIView? {
		get {
			return tapRecogniser.view
		}
		set {
			let oldValue = tapRecogniser.view
			if newValue === oldValue { return }
			oldValue?.removeGestureRecognizer(tapRecogniser)
		//	oldValue?.removeGestureRecognizer(panRecogniser)
			newValue?.addGestureRecognizer(tapRecogniser)
		//	newValue?.addGestureRecognizer(panRecogniser)
		}
	}

	@objc func tapRecognised(by recognizer: UITapGestureRecognizer) {
		guard recognizer.state == .recognized
		else { return }
		let point = recognizer.location(in: collectionView)
		if let animator = gp.animator {
			// Already have an animator, so stop it at its current position and then
			// animate to select the nearest integral position
			_ = animator
		} else {
			// New animator. See if tap would change selection.
			guard let position = positionHitBy(point)
			else { return } // nothing hit
			let delta = position > 0 ? position : -1
			let startSelectee = selecteeIndex
			let endSelectee = rotate(startSelectee, by: Int(delta), within: itemCount)
			let selecteeChange = (startSelectee, endSelectee)

			if !gh.animateSelection {
				self.invalidateLayout()
				selecteeIndex = endSelectee
				return
			}

			let a = makeAnimator(for: .tap, at: position, delta: delta)
			a.addCompletion
				{ (finishingAt: UIViewAnimatingPosition) in
					var newSelectee: Int
					switch finishingAt {
						case .start:
							newSelectee = startSelectee
						case .end:
							newSelectee = endSelectee
						case .current:
							let distanceTraversed = a.fractionComplete * delta
							let newPos = rotate(CGFloat(startSelectee), by: distanceTraversed, within: CGFloat(self.itemCount))
							newSelectee = Int(round(newPos))
					}
					self.gp.animator = nil
						self.invalidateLayout()
					self.selecteeIndex = newSelectee
					self.gp.selecteeIndexAt = (newSelectee, newSelectee)
				//	self.animator(a, stoppedSelecteeChange: selecteeChange, finishingAt: $0)
				}
			gp.animator = a
			gp.selecteeIndexAt = selecteeChange
			a.startAnimation()
		}
	}

	@objc func panRecognised(by recognizer: UIPanGestureRecognizer) {
	}

/*
	func animator(_ animator: UIViewPropertyAnimator, stoppedSelecteeChange: (animationStart: Int, animationEnd: Int), finishingAt: UIViewAnimatingPosition) {
		var newSelectee: Int
		switch finishingAt {
			case .start:
				newSelectee = selecteeIndexAt.animationStart
			case .end:
				newSelectee = selecteeIndexAt.animationEnd
			case .current:
				let distanceTraversed = animator.fractionComplete * ??? - need
				newSelectee = rotate(CGFloat(selecteeIndexAt.animationStart), by: distanceTraversed, within: CGFloat(itemCount))
		}
		selecteeIndex = newSelectee
	}
*/

	func indexPathHitBy(_ pt: CGPoint) -> IndexPath? {
		if let pos = positionHitBy(pt) {
			let ip = indexPath(at: pos)
			return ip
		}
		return nil
	}

	func positionHitBy(_ pt: CGPoint, withPartialOffset offset: CGFloat = 0) -> CGFloat? {
		for i in 0...wp.spreadCount {
			let p = CGFloat(i)
			if let f = frame(at: p + offset), f.contains(pt) {
				return p
			}
		}
		return nil
	}

	func makeAnimator(for gesture: Gesture, at position: CGFloat, delta: CGFloat) -> UIViewPropertyAnimator {
		switch gesture {
			case .tap:
				let animations = makeAnimationBlockForRepositioning(by: delta)
				let a = UIViewPropertyAnimator(duration: gh.selectDuration, curve: .easeInOut, animations: animations)
				return a
			case .pan_start:
				return UIViewPropertyAnimator()
			case .pan_release(_)://(let speed):
				return UIViewPropertyAnimator()
		}
	}

	func forEachCell(do doToCell: (_ cell: UICollectionViewCell, _ indexPath: IndexPath, _ ordinal: Int)->Void) {
		guard let cv = collectionView else { return }
		let currentSelecteeIndex = selecteeIndex
		var instanceIdx = 0
		cv.subviews.forEach { (view) in
			if let cell = view as? UICollectionViewCell {
				let ordinal = (self.itemCount - 1) - instanceIdx
				let item = rotate(ordinal, by: currentSelecteeIndex, within: itemCount)
				let ip = IndexPath(item: item, section: 0)
				doToCell(cell, ip, ordinal)
				instanceIdx += 1
			}
		}
	}

	func makeAnimationBlockForRepositioning(by delta: CGFloat) -> ()->Void {
		return {
			let wp = self.wp
			/*	What this does and how:
				-	we want to move each cell by amount delta
				-	we setup key frame animations that would move each cell's properties full circle
					-	i.e. completely around the positioning loop returning to the start position
				-	in order to subsample the key frame transitions, we put them inside a group animation with a shorter duration
					-	the group animation duration is set to the overall duration we want
					-	the keyframe animation durations are chosen such that group / kfa duration is the fraction of the animation that we want to show, i.e. delta / full circle
				-	when provide the position key frame animation with a bezier path to follow
					-	this is rotated from the original path, such that the starting point we need is at the begining
					-	it may seem that this rotation could have been achieved using the original path and setting a start time offset for the KFA, however this would not cope with the wrap around that is needed for at least one of the cells each time; the path rotation functions we use instead can cope with wrap around
			*/
			let kfaDuration = self.gh.selectDuration * Double(self.itemCount + 1) / abs(Double(delta))
			let groupDuration = self.gh.selectDuration
			let transitionalOffsetWas = self.transitionalOffset //+ 0.2
			self.transitionalOffset = transitionalOffsetWas - delta //+ 0.5
			self.forEachCell
			{ (cell, indexPath, ordinal) in
				guard let attributes = self.layoutAttributesForItem(at: indexPath)
				else { return }
				let verboseForThisCell = self.gh.verbose && (indexPath.item == self.gp.selecteeIndexAt.animationStart || indexPath.item == self.gp.selecteeIndexAt.animationEnd)
				if self.gh.bypassApply {
					// try just frame for now
					let frame = attributes.frame
					cell.bounds = CGRect(frame.size)
					cell.center = frame.center

					var animations: [CAAnimation] = []

					var kfa = CAKeyframeAnimation(keyPath: "position")
					kfa.path = wp.locus.path(from: ordinal, forwards: delta < 0)
					kfa.duration = kfaDuration
					animations.append(kfa)

					if self.gh.animateBounds {
						kfa = CAKeyframeAnimation(keyPath: "bounds.size")
						let scales = wp.scaleProgression.values(from: CGFloat(ordinal), forwards: delta < 0)
						let values = scales.map { wp.faceRect.size * $0 }
						kfa.values = values
						kfa.duration = kfaDuration
						animations.append(kfa)
					}

					if self.gh.animateAlpha {
						kfa = CAKeyframeAnimation(keyPath: "opacity")
						kfa.values = wp.alphaProgression.values(from: CGFloat(ordinal), forwards: delta < 0)
						kfa.duration = kfaDuration
						animations.append(kfa)
					}

					let ga = CAAnimationGroup()
					ga.animations = animations
					ga.duration = groupDuration
					ga.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
					cell.layer.removeAnimation(forKey: "position")
					if self.gh.animateBounds {
						cell.layer.removeAnimation(forKey: "bounds.size")
					}
					cell.layer.add(ga, forKey: "position")
				} else {
					cell.apply(attributes)
				}
				if verboseForThisCell, ordinal == -1 {
					cell.layer.animationKeys()?.forEach { (k) in
						var s = "nil"
						if let a = cell.layer.animation(forKey: k) {
							s = a.debugDescription
						}
						print("cell[\(indexPath.item)].layer.animation[\"\(k)\"]=\(s)")
					}
				}
			}
			self.transitionalOffset = transitionalOffsetWas
			self.collectionView?.layoutIfNeeded()
		}
	}
}
//	...would make sense that cell.apply(attributes) is internally gated to prevent devs
//	using apply() arbitrarily -> cell has to check collectionView (via superview or layer
//	delegate ref) to see whether apply is allowed, and ignore if not
//	cell.setNeedsLayout() - makes no difference
	/*
	-	animation of the frame is broken down into animation of the 'centre' and the size
	-	animation of 'centre' is a misnomer; its actually animation of the position of the layer anchor, which by default is at 0.5, 0.5
	-	first problem: our locus is top left, i.e. anchor at 0,0
		-	we can't create the locus for anchor at 0.5,0.5 because we don't have the capability to make a bezier variably offset by the animating scale - it's not an arbitrarily solvable
		-	to work around, we would have to change the layer's anchor to 0,0 and compensate position (without animation), animate along the locus, and then reverse the anchor offset - not quick, not easy
	-	second problem: the face to back of pack transition has to traverse in the same time as moving between two spread positions -> need a two-part timing function

	so...
	-	stick with the basic animations
	*/



// MARK: -
public extension CarouselLayout.Params
{
	init?(_ params: AnyJSONObject)
	{
		guard case .dictionary(let values) = params
		else { Log.error("CarouselLayout.Params.init(AnyJSONObject) expected a dictionary at root level instead of: \(params)") ; return nil }
		var errors = false

		getSpreadCount:
		if let obj = values["spreadCount"] {
			guard let i = obj.asInt
			else { Log.error("CarouselLayout.Params.init(AnyJSONObject) expected integer for spreadCount instead of: \(obj)") ; errors = true ; break getSpreadCount }
			spreadCount = i
		}

		getPackScale:
		if let obj = values["packScale"] {
			guard let d = obj.asDouble, d > 0, d <= 1
			else { Log.error("CarouselLayout.Params.init(AnyJSONObject) expected a float > 0 and <= 1 for packScale instead of: \(obj)") ; errors = true ; break getPackScale }
			packScale = CGFloat(d)
		}

		getPackPosition:
		if let obj = values["packPosition"] {
			guard
				case .array(let values) = obj, values.count == 2,
				let x = values[0].asDouble, let y = values[1].asDouble,
				x >= 0, x <= 1, y >= 0, y <= 1
			else { Log.error("CarouselLayout.Params.init(AnyJSONObject) expected an array of two floats in the range 0.0 .. 1.0 for packPosition instead of: \(obj)") ; errors = true ; break getPackPosition }
			packPosition = CGPoint(x: x, y: y)
		}

		getFacePosition:
		if let obj = values["facePosition"] {
			guard
				case .array(let values) = obj, values.count == 2,
				let x = values[0].asDouble, let y = values[1].asDouble,
				x >= 0, x <= 1, y >= 0, y <= 1
			else { Log.error("CarouselLayout.Params.init(AnyJSONObject) expected an array of two floats in the range 0.0 .. 1.0 for facePosition instead of: \(obj)") ; errors = true ; break getFacePosition }
			facePosition = CGPoint(x: x, y: y)
		}

		getFaceSize:
		if let obj = values["faceSize"] {
			guard
				case .array(let values) = obj, values.count == 2,
				let width = values[0].asDouble, let height = values[1].asDouble,
				width > 0, height > 0
			else { Log.error("CarouselLayout.Params.init(AnyJSONObject) expected an array of two positive floats for faceSize instead of: \(obj)") ; errors = true ; break getFaceSize }
			faceSize = CGSize(width: width, height: height)
		}

		getLocusControlPoints:
		if let obj = values["locusControlPoints"] {
			var dd = [Double]()
			let gatherDoubles = { (o: AnyJSONObject) -> Double? in
				guard let d = o.asDouble else { return nil } ; dd.append(d) ; return d
			}
			guard
				case .array(let values) = obj,
				values.count == 0 || values.count == 2 || values.count == 4,
				values.count == values.compactMap(gatherDoubles).count
			else { Log.error("CarouselLayout.Params.init(AnyJSONObject) expected an array of 0, 2 or 4 floats for locusControlPoints instead of: \(obj)") ; errors = true ; break getLocusControlPoints }
			switch dd.count {
				case 0:
					break
				case 2:
					locusControlPoints[2] = CGFloat((0.0 + dd[0] * 2.0)       / 3.0)
					locusControlPoints[3] = CGFloat((0.0 + dd[1] * 2.0)       / 3.0)
					locusControlPoints[4] = CGFloat((      dd[0] * 2.0 + 1.0) / 3.0)
					locusControlPoints[5] = CGFloat((      dd[1] * 2.0 + 1.0) / 3.0)
				case 4:
					locusControlPoints[2] = CGFloat(dd[0])
					locusControlPoints[3] = CGFloat(dd[1])
					locusControlPoints[4] = CGFloat(dd[2])
					locusControlPoints[5] = CGFloat(dd[3])
				default:
					break
			}
		}

		getReturnOvershoot:
		if let obj = values["returnOvershoot"] {
			guard let d = obj.asDouble
			else { Log.error("CarouselLayout.Params.init(AnyJSONObject) expected a float for returnOvershoot instead of: \(obj)") ; errors = true ; break getReturnOvershoot }
			returnOvershoot = CGFloat(d)
		}

		getShowLocus:
		if let obj = values["showLocus"] {
			guard let b = obj.asBool
			else { Log.error("CarouselLayout.Params.init(AnyJSONObject) expected boolean (true,yes,1/false,no,0 etc.) for showLocus instead of: \(obj)") ; errors = true ; break getShowLocus }
			showLocus = b
		}

		if errors {
			return nil
		}
	}
}



extension CarouselLayout.WorkingParams : Equatable
{
	static func ==(lhs: CarouselLayout.WorkingParams, rhs: CarouselLayout.WorkingParams) -> Bool {
		return lhs.evaluatedForSize == rhs.evaluatedForSize
			&& lhs.spreadCount == rhs.spreadCount
			&& lhs.faceRect == rhs.faceRect
			&& lhs.packRect == rhs.packRect
			&& lhs.locus == rhs.locus
	}
}



extension CarouselLayout.Locus : Equatable
{
	public static func ==(lhs: CarouselLayout.Locus, rhs: CarouselLayout.Locus) -> Bool {
		return lhs.points == rhs.points
	}
}



// MARK: - Debug: LocusView
extension CarouselLayout
{
	open class LocusView : UIView {
		public var locus:		Locus? = nil { didSet { setNeedsDisplay() } }
		func commonInit() {
			self.backgroundColor = .clear
			self.isOpaque = false
			self.autoresizingMask = [.flexibleHeight, .flexibleWidth]
			self.isUserInteractionEnabled = false
		}
		public override init(frame: CGRect) { super.init(frame: frame) ; commonInit() }
		public required init?(coder: NSCoder) { super.init(coder: coder) ; commonInit() }
		open override func draw(_ rect: CGRect) {
			guard
				let context = UIGraphicsGetCurrentContext(),
				let locus = locus, !locus.points.isEmpty
			else { return }
			let path = locus.asCGPath
			context.addPath(path)
			context.setStrokeColor(UIColor.orange.withAlphaComponent(0.6).cgColor)
			context.setLineWidth(4)
			context.strokePath()
		}
	}
	open func showLocus(_ locus: Locus?) -> Bool {
		var didChange = false
		if let locus = locus {
			if	locusView == nil {
				locusView = LocusView(frame: .zero)
			}
			if let cv = collectionView, let locusView = locusView {
				locusView.frame = cv.bounds
				if locusView.superview !== cv {
					cv.insertSubview(locusView, at: cv.subviews.count)
				}
				locusView.layer.zPosition = CGFloat(cv.subviews.count)
			}
			didChange = locus != locusView?.locus
			locusView?.locus = locus
		} else {
			locusView?.removeFromSuperview()
			didChange = nil != locusView?.locus
			locusView?.locus = nil
		}
		return didChange
	}
}



extension UIViewAnimating {
	func stopAnimatingWithoutApplyingFinalValues()	{ stopAnimation(true) }
	func stopAnimatingAndApplyFinalValues()			{ stopAnimation(false) }
}


