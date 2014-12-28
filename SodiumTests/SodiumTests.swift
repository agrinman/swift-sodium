//
//  SodiumTests.swift
//  SodiumTests
//
//  Created by Frank Denis on 12/27/14.
//  Copyright (c) 2014 Frank Denis. All rights reserved.
//

import XCTest
import Sodium

extension String {
    func toData() -> NSData? {
        return self.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
    }
}

extension NSData {
    func toString() -> String? {
        return NSString(data: self, encoding: NSUTF8StringEncoding)
    }
}

class SodiumTests: XCTestCase {
    let sodium = Sodium()
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testGenericHash() {
        let message = "My Test Message".toData()!
        let h1 = sodium.utils.bin2hex(sodium.genericHash.hash(message)!)!
        XCTAssert(h1 == "64a9026fca646c31df54426ad15a341e2444d8a1863d57eb27abecf239609f75")
        
        let key = sodium.utils.hex2bin("64 a9 02 6f ca 64 6c 31 df 54", ignore: " ")
        let h2 = sodium.utils.bin2hex(sodium.genericHash.hash(message, key: key)!)!
        XCTAssert(h2 == "1773f324cba2e7b0017e32d7e44f7afd1036c5d4ef9a80ae0e52e95a629844cd")
        
        let h3 = sodium.utils.bin2hex(sodium.genericHash.hash(message, key: key, outputLength: sodium.genericHash.BytesMax)!)!
        XCTAssert(h3 == "cba85e39f2d03923b2f66aba99b204333edc34a8443ab1700f7920c7abcc6639963a953f35162a520b21072ab906457d21f1645e6e3985858ee95a84d0771f07")
        
        let s1 = sodium.genericHash.initStream()!
        s1.update(message)
        let h4 = sodium.utils.bin2hex(s1.final()!)!
        XCTAssert(h4 == h1)
        
        let s2 = sodium.genericHash.initStream(key: key)!
        s2.update(message)
        let h5 = sodium.utils.bin2hex(s2.final()!)!
        XCTAssert(h5 == h2)
        
        let s3 = sodium.genericHash.initStream(key, outputLength: sodium.genericHash.BytesMax)!
        s3.update(message)
        let h6 = sodium.utils.bin2hex(s3.final()!)!
        XCTAssert(h6 == h3)
    }
    
    func testRandomBytes() {
        let randomLen = 100 + Int(sodium.randomBytes.uniform(100))
        let random1 = sodium.randomBytes.buf(randomLen)!
        let random2 = sodium.randomBytes.buf(randomLen)!
        XCTAssert(random1.length == randomLen)
        XCTAssert(random2.length == randomLen)
        XCTAssert(random1 != random2)
        
        var c1 = 0
        let ref1 = self.sodium.randomBytes.random()
        for _ in (0..<100) {
            if sodium.randomBytes.random() == ref1 {
                c1++
            }
        }
        XCTAssert(c1 < 10)
        
        var c2 = 0
        let ref2 = self.sodium.randomBytes.uniform(100_000)
        for _ in (0..<100) {
            if sodium.randomBytes.uniform(100_000) == ref2 {
                c2++
            }
        }
        XCTAssert(c2 < 10)
    }
    
    func testUtils() {
        let dataToZero = NSMutableData(bytes: UnsafePointer([1, 2, 3, 4] as [UInt8]), length: 4)
        sodium.utils.zero(dataToZero)
        XCTAssert(dataToZero.length == 0)
        
        let eq1 = NSData(bytes: UnsafePointer([1, 2, 3, 4] as [UInt8]), length: 4)
        let eq2 = NSData(bytes: UnsafePointer([1, 2, 3, 4] as [UInt8]), length: 4)
        let eq3 = NSData(bytes: UnsafePointer([1, 2, 3, 5] as [UInt8]), length: 4)
        let eq4 = NSData(bytes: UnsafePointer([1, 2, 3] as [UInt8]), length: 3)
        XCTAssert(sodium.utils.equals(eq1, to: eq2))
        XCTAssert(!sodium.utils.equals(eq1, to: eq3))
        XCTAssert(!sodium.utils.equals(eq1, to: eq4))
        
        let bin = sodium.utils.hex2bin("deadbeef")!
        XCTAssert(bin.description == "<deadbeef>")
        let hex = sodium.utils.bin2hex(bin)
        XCTAssert(hex == "deadbeef")
        let bin2 = sodium.utils.hex2bin("de-ad be:ef", ignore: ":- ")!
        XCTAssert(bin2 == bin)
    }
}
