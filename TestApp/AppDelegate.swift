/*
	AppDelegate.swift
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
import T0Utils
import BrandKit


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?
	static var brandAt: URL? = nil

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		Brand.makeDefaultBrandOnce = { return DefaultBrand(storage: Bundle.main.bundleURL) }

		let fm = FileManager.default
		let docsAt = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
		if 	let src = Bundle.main.url(forResource: "appearance", withExtension: "json") {
			AppDelegate.brandAt = src.deletingLastPathComponent()
			do {
				let dst = docsAt.appendingPathComponent("appearance.json")
				if !fm.fileExists(atPath: dst.path) {
					try fm.copyItem(at: src, to: dst)
				}
				AppDelegate.brandAt = docsAt
			} catch {
				T0Logging.error("copying appearance got \(error)")
			}
		}
		return true
	}

}



class DefaultBrand : Brand
{
	override func color(_ kind: ColorKind) -> Unified.Color					{ return Brand.kInvalidColor }
	override func metric(_ kind: MetricKind) -> CGFloat						{ return Brand.kInvalidMetric }
	override func font(_ kind: FontKind) -> Unified.Font					{ return Brand.kInvalidFont }
	override func textAttributes(_ kind: TextAttributesKind) -> Unified.TextAttributes { return Brand.kInvalidTextAttributes }
	override func placement(_ kind: PlacementKind) -> Brand.Placement	{ return Brand.Placement() }
	override func image(_ kind: ImageKind) -> Unified.Image					{ return Brand.kInvalidImage }
	override func buttonStyle(_ kind: ButtonStyleKind) -> ButtonStyle		{ return Brand.kInvalidButtonStyle }
	override func parameter(_ kind: ParameterKind) -> AnyJSONObject			{ return AnyJSONObject.null }
}



