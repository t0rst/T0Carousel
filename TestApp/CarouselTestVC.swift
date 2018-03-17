/*
	CarouselTestVC.swift
	T0Carousel

	Created by Torsten Louland on 17/02/2018.

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

import UIKit
import CwlUtils
import BrandKit
import T0Carousel


extension Brand.ParameterKind {
	static let carousel_params =				Brand.ParameterKind("carousel_params")
	static let gesture_handling =				Brand.ParameterKind("gesture_handling")
}



class CarouselTestVC : UIViewController {
	@IBOutlet weak var collectionView: UICollectionView!
	@IBOutlet weak var carouselLayout: CarouselLayout!

	var cellCount =				10

	override func viewDidLoad() {
		super.viewDidLoad()
		let brand = Brand(storage: AppDelegate.brandAt!)
		brand.load(coordinate: true)
		print(brand.printEditingPrompt())
		self.brand = brand
		collectionView.backgroundView = nil
		collectionView.backgroundColor = .clear
		collectionView.allowsMultipleSelection = false
		collectionView.allowsSelection = true
		collectionView.reloadData()
	}

	// MARK: - Brand

	var brand:					Brand? = nil {
		willSet {
			if newValue === brand { return }
			_brandObserver = nil
			_brandObserved = nil
		}
		didSet {
			if oldValue === brand { return }
			if nil == oldValue {
				self.observeBrand() // apply first brand immediately, to avoid unsightly unbranded appearance
			} else {
				DispatchQueue.main.async
					{ self.observeBrand() }
			}
		}
	}
	private var _brandObserver:	KeyValueObserver? = nil
	private var _brandObserved: Brand? = nil
	private func observeBrand() {
		guard let brand = self.brand, _brandObserved !== brand else { return }
		_brandObserved = brand
		_brandObserver = KeyValueObserver(source: brand, keyPath: "sequence", options: [.initial,.new])
			{ [weak self] (values, reason) in
				self?.applyBrand()
			}
	}
	func applyBrand() {
		if let brand = self.brand, isViewLoaded {
			applyBrand(brand)
		}
	}

	func applyBrand(_ brand: Brand) {
		let paramJSO = brand.parameter(.carousel_params)
		if	let params = CarouselLayout.Params(paramJSO) {
			carouselLayout.params = params
		}
		let ghJSO = brand.parameter(.gesture_handling)
		if	let gh = CarouselLayout.GestureHandling(ghJSO) {
			carouselLayout.gh = gh
		}
	}
}



extension CarouselTestVC : UICollectionViewDataSource {
	func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int
	{
		return section == 0 ? cellCount : 0
	}

	func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell
	{
		let cell = cv.dequeueReusableCell(withReuseIdentifier: "carouselTestCell", for: ip)
		guard let ctc = cell as? CarouselTestCell else { return cell }

		ctc.tag = ip.item
		ctc.id = "\(ip.item)"
		ctc.color = UIColor.init(hue: CGFloat(ip.item)/CGFloat(cellCount), saturation: 0.7, brightness: 0.8, alpha: 1.0)

		if nil == cell.backgroundView { cell.backgroundView = UIView() }
		if let bgv = cell.backgroundView {
			bgv.backgroundColor = .clear
			bgv.layer.borderWidth = 8
			bgv.layer.borderColor = UIColor.black.withAlphaComponent(0.05).cgColor
		}

		if nil == cell.selectedBackgroundView { cell.selectedBackgroundView = UIView() }
		if let bgv = cell.selectedBackgroundView {
			bgv.backgroundColor = .clear
			bgv.layer.borderWidth = 8
			bgv.layer.borderColor = UIColor.blue.withAlphaComponent(0.25).cgColor
		}

		return cell
	}
}



extension CarouselTestVC : UICollectionViewDelegate {
}



class CarouselTestCell : UICollectionViewCell {
	@IBOutlet weak var foregroundView: UIView!

	override func awakeFromNib() {
		super.awakeFromNib()
	}

	override func awakeAfter(using aDecoder: NSCoder) -> Any? {
		return super.awakeAfter(using: aDecoder)
	}

	var id: String = "" {
		didSet {
			if id == oldValue { return }
			foregroundView.subviews.flatMap({ $0 as? UILabel }).forEach { $0.text = id }
		}
	}

	var color: UIColor = .white {
		didSet {
			if color == oldValue { return }
			foregroundView.backgroundColor = color.withAlphaComponent(0.5)
			foregroundView.subviews.forEach { $0.backgroundColor = color }
		}
	}
}



