/*
	T0CarouselTestCase.swift
	T0Carousel

	Created by Torsten Louland on 01/03/2018.

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



import XCTest
import T0Carousel



class T0CarouselTestCase : XCTestCase {

	override func setUp()			{ super.setUp() /**/ }
	override func tearDown()		{ /**/ super.tearDown() }

	func test01_CarouselLayout_Progression_value() {
		let a = CGFloat(1e-10)

		let p1c = CarouselLayout.Progression([0.0, 1.0], .continuous)
		// progression repeats 0 --> 1 --> 0
		XCTAssertEqual(p1c.value(at: 0.0), CGFloat(0.0), accuracy: a)
		XCTAssertEqual(p1c.value(at: 0.1), CGFloat(0.1), accuracy: a)
		XCTAssertEqual(p1c.value(at: 1.0), CGFloat(1.0), accuracy: a)
		XCTAssertEqual(p1c.value(at: 1.1), CGFloat(0.9), accuracy: a)
		XCTAssertEqual(p1c.value(at: 1.9), CGFloat(0.1), accuracy: a)
		XCTAssertEqual(p1c.value(at: 2.0), CGFloat(0.0), accuracy: a)
		XCTAssertEqual(p1c.value(at: 2.1), CGFloat(0.1), accuracy: a)
		XCTAssertEqual(p1c.value(at: -0.1), CGFloat(0.1), accuracy: a)
		XCTAssertEqual(p1c.value(at: -1.0), CGFloat(1.0), accuracy: a)
		XCTAssertEqual(p1c.value(at: -1.1), CGFloat(0.9), accuracy: a)
		XCTAssertEqual(p1c.value(at: -1.9), CGFloat(0.1), accuracy: a)
		XCTAssertEqual(p1c.value(at: -2.0), CGFloat(0.0), accuracy: a)
		XCTAssertEqual(p1c.value(at: -2.1), CGFloat(0.1), accuracy: a)

		let p1d = CarouselLayout.Progression([0.0, 1.0], .discrete)
		// progression repeats [0,1)
		XCTAssertEqual(p1d.value(at: 0.0), CGFloat(0.0), accuracy: a)
		XCTAssertEqual(p1d.value(at: 0.1), CGFloat(0.1), accuracy: a)
		XCTAssertEqual(p1d.value(at: 0.99999), CGFloat(0.99999), accuracy: a)
		XCTAssertEqual(p1d.value(at: 1.0), CGFloat(0.0), accuracy: a)
		XCTAssertEqual(p1d.value(at: 1.1), CGFloat(0.1), accuracy: a)
		XCTAssertEqual(p1d.value(at: 1.9), CGFloat(0.9), accuracy: a)
		XCTAssertEqual(p1d.value(at: 2.0), CGFloat(0.0), accuracy: a)
		XCTAssertEqual(p1d.value(at: 2.1), CGFloat(0.1), accuracy: a)
		XCTAssertEqual(p1d.value(at: 3.0), CGFloat(0.0), accuracy: a)
		XCTAssertEqual(p1d.value(at: -0.1), CGFloat(0.9), accuracy: a)
		XCTAssertEqual(p1d.value(at: -1.0), CGFloat(0.0), accuracy: a)
		XCTAssertEqual(p1d.value(at: -1.1), CGFloat(0.9), accuracy: a)
		XCTAssertEqual(p1d.value(at: -1.9), CGFloat(0.1), accuracy: a)
		XCTAssertEqual(p1d.value(at: -2.0), CGFloat(0.0), accuracy: a)
		XCTAssertEqual(p1d.value(at: -2.1), CGFloat(0.9), accuracy: a)

		let p2c = CarouselLayout.Progression([0.0, 1.0, 2.0], .continuous)
		// progression repeats 0 --> 1 --> 2 --> 0
		XCTAssertEqual(p2c.value(at: 0.0), CGFloat(0.0), accuracy: a)
		XCTAssertEqual(p2c.value(at: 0.1), CGFloat(0.1), accuracy: a)
		XCTAssertEqual(p2c.value(at: 1.0), CGFloat(1.0), accuracy: a)
		XCTAssertEqual(p2c.value(at: 1.1), CGFloat(1.1), accuracy: a)
		XCTAssertEqual(p2c.value(at: 1.9), CGFloat(1.9), accuracy: a)
		XCTAssertEqual(p2c.value(at: 2.0), CGFloat(2.0), accuracy: a)
		XCTAssertEqual(p2c.value(at: 2.1), CGFloat(1.8), accuracy: a) // 0.1 along return path
		XCTAssertEqual(p2c.value(at: -0.1), CGFloat(0.2), accuracy: a)
		XCTAssertEqual(p2c.value(at: -1.0), CGFloat(2.0), accuracy: a)
		XCTAssertEqual(p2c.value(at: -1.1), CGFloat(1.9), accuracy: a)
		XCTAssertEqual(p2c.value(at: -1.9), CGFloat(1.1), accuracy: a)
		XCTAssertEqual(p2c.value(at: -2.0), CGFloat(1.0), accuracy: a)
		XCTAssertEqual(p2c.value(at: -2.1), CGFloat(0.9), accuracy: a)

		let p2d = CarouselLayout.Progression([0.0, 1.0, 2.0], .discrete)
		// progression repeats [0,2)
		XCTAssertEqual(p2d.value(at: 0.0), CGFloat(0.0), accuracy: a)
		XCTAssertEqual(p2d.value(at: 0.1), CGFloat(0.1), accuracy: a)
		XCTAssertEqual(p2d.value(at: 1.0), CGFloat(1.0), accuracy: a)
		XCTAssertEqual(p2d.value(at: 1.1), CGFloat(1.1), accuracy: a)
		XCTAssertEqual(p2d.value(at: 1.9), CGFloat(1.9), accuracy: a)
		XCTAssertEqual(p2d.value(at: 1.99999), CGFloat(1.99999), accuracy: a)
		XCTAssertEqual(p2d.value(at: 2.0), CGFloat(0.0), accuracy: a)
		XCTAssertEqual(p2d.value(at: 2.1), CGFloat(0.1), accuracy: a)
		XCTAssertEqual(p2d.value(at: -0.1), CGFloat(1.9), accuracy: a)
		XCTAssertEqual(p2d.value(at: -1.0), CGFloat(1.0), accuracy: a)
		XCTAssertEqual(p2d.value(at: -1.1), CGFloat(0.9), accuracy: a)
		XCTAssertEqual(p2d.value(at: -1.9), CGFloat(0.1), accuracy: a)
		XCTAssertEqual(p2d.value(at: -2.0), CGFloat(0.0), accuracy: a)
		XCTAssertEqual(p2d.value(at: -2.1), CGFloat(1.9), accuracy: a)
	}
}
